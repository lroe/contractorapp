import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from flask import Flask, render_template, request, redirect, url_for, session, flash, jsonify
from sqlalchemy import func
from app.database import SessionLocal
from app import models
import bcrypt
from datetime import date, datetime
import uuid

app = Flask(__name__)
app.secret_key = os.urandom(24)

# ─── DB Helpers ───────────────────────────────────────────────────────────────

def get_db():
    return SessionLocal()

def close_db(db):
    db.close()

# ─── Auth ─────────────────────────────────────────────────────────────────────

def login_required(f):
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if 'user_id' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated

@app.route('/', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        phone = request.form.get('phone', '').strip()
        password = request.form.get('password', '').strip()
        db = get_db()
        user = db.query(models.User).filter(models.User.phone == phone).first()
        close_db(db)
        if user and bcrypt.checkpw(password.encode(), user.password_hash.encode()):
            if user.role not in ('material_manager', 'owner'):
                flash('Access denied. This portal is for Material Managers only.', 'error')
                return redirect(url_for('login'))
            session['user_id'] = str(user.id)
            session['user_name'] = user.name
            session['user_role'] = user.role
            return redirect(url_for('dashboard'))
        flash('Invalid credentials.', 'error')
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

# ─── Dashboard ────────────────────────────────────────────────────────────────

@app.route('/dashboard')
@login_required
def dashboard():
    db = get_db()
    pending_pos = db.query(models.PurchaseOrder).filter(models.PurchaseOrder.status == 'draft').count()
    active_vendors = db.query(models.Vendor).filter(models.Vendor.is_active == True).count()
    total_materials = db.query(models.Material).count()
    pending_transfers = db.query(models.TransferNote).filter(models.TransferNote.status == 'pending').count()
    total_waste = db.query(func.sum(models.WasteLog.quantity)).scalar() or 0

    # Recent POs
    recent_pos = db.query(models.PurchaseOrder).order_by(
        models.PurchaseOrder.created_at.desc()
    ).limit(5).all()

    # Low stock alerts
    low_stock = []
    inventory = db.query(models.ProjectInventory).all()
    for item in inventory:
        mat = db.query(models.Material).filter(models.Material.id == item.material_id).first()
        proj = db.query(models.Project).filter(models.Project.id == item.project_id).first()
        if mat and float(item.current_quantity) < float(mat.min_stock_level or 0):
            low_stock.append({
                'project': proj.name if proj else 'Unknown',
                'material': mat.name,
                'unit': mat.unit,
                'current': float(item.current_quantity),
                'min': float(mat.min_stock_level or 0),
            })

    close_db(db)
    return render_template('dashboard.html',
        pending_pos=pending_pos,
        active_vendors=active_vendors,
        total_materials=total_materials,
        pending_transfers=pending_transfers,
        total_waste=float(total_waste),
        recent_pos=recent_pos,
        low_stock=low_stock,
    )

# ─── Vendors ──────────────────────────────────────────────────────────────────

@app.route('/vendors')
@login_required
def vendors():
    db = get_db()
    all_vendors = db.query(models.Vendor).order_by(models.Vendor.name).all()
    materials = db.query(models.Material).order_by(models.Material.name).all()
    close_db(db)
    return render_template('vendors.html', vendors=all_vendors, materials=materials)

@app.route('/vendors/add', methods=['POST'])
@login_required
def add_vendor():
    db = get_db()
    v = models.Vendor(
        name=request.form['name'],
        phone=request.form.get('phone'),
        email=request.form.get('email'),
        address=request.form.get('address'),
        gstin=request.form.get('gstin'),
    )
    db.add(v)
    db.commit()
    close_db(db)
    flash(f'Vendor "{v.name}" added successfully.', 'success')
    return redirect(url_for('vendors'))

@app.route('/vendors/<vendor_id>/deactivate', methods=['POST'])
@login_required
def deactivate_vendor(vendor_id):
    db = get_db()
    v = db.query(models.Vendor).filter(models.Vendor.id == uuid.UUID(vendor_id)).first()
    if v:
        v.is_active = False
        db.commit()
        flash(f'Vendor "{v.name}" deactivated.', 'info')
    close_db(db)
    return redirect(url_for('vendors'))

@app.route('/vendor-prices/add', methods=['POST'])
@login_required
def add_vendor_price():
    db = get_db()
    price = models.VendorPrice(
        vendor_id=uuid.UUID(request.form['vendor_id']),
        material_id=uuid.UUID(request.form['material_id']),
        price_per_unit=float(request.form['price_per_unit']),
        notes=request.form.get('notes'),
    )
    db.add(price)
    db.commit()
    close_db(db)
    flash('Price added.', 'success')
    return redirect(url_for('vendors'))

@app.route('/vendor-prices/<material_id>')
@login_required
def vendor_prices(material_id):
    db = get_db()
    prices = db.query(models.VendorPrice).filter(
        models.VendorPrice.material_id == uuid.UUID(material_id)
    ).order_by(models.VendorPrice.price_per_unit).all()
    mat = db.query(models.Material).filter(models.Material.id == uuid.UUID(material_id)).first()
    close_db(db)
    return render_template('vendor_prices.html', prices=prices, material=mat)

# ─── Purchase Orders ──────────────────────────────────────────────────────────

@app.route('/purchase-orders')
@login_required
def purchase_orders():
    db = get_db()
    pos = db.query(models.PurchaseOrder).order_by(models.PurchaseOrder.created_at.desc()).all()
    vendors = db.query(models.Vendor).filter(models.Vendor.is_active == True).all()
    projects = db.query(models.Project).filter(models.Project.status == 'active').all()
    materials = db.query(models.Material).order_by(models.Material.name).all()
    close_db(db)
    return render_template('purchase_orders.html', pos=pos, vendors=vendors, projects=projects, materials=materials)

@app.route('/purchase-orders/create', methods=['POST'])
@login_required
def create_po():
    import random
    db = get_db()
    po_number = f"PO-{date.today().strftime('%Y%m')}-{random.randint(1000,9999)}"
    po = models.PurchaseOrder(
        project_id=uuid.UUID(request.form['project_id']),
        vendor_id=uuid.UUID(request.form['vendor_id']),
        po_number=po_number,
        status='draft',
        raised_by=uuid.UUID(session['user_id']),
        expected_delivery=request.form.get('expected_delivery') or None,
        remarks=request.form.get('remarks'),
        total_amount=0,
    )
    db.add(po)
    db.flush()

    material_ids = request.form.getlist('material_id[]')
    quantities = request.form.getlist('quantity[]')
    unit_prices = request.form.getlist('unit_price[]')
    total = 0
    for m_id, qty, price in zip(material_ids, quantities, unit_prices):
        if m_id and qty:
            item = models.PurchaseOrderItem(
                po_id=po.id,
                material_id=uuid.UUID(m_id),
                quantity=float(qty),
                unit_price=float(price or 0),
            )
            db.add(item)
            total += float(qty) * float(price or 0)

    po.total_amount = total
    db.commit()
    close_db(db)
    flash(f'Purchase Order {po_number} created.', 'success')
    return redirect(url_for('purchase_orders'))

@app.route('/purchase-orders/<po_id>/approve', methods=['POST'])
@login_required
def approve_po(po_id):
    db = get_db()
    po = db.query(models.PurchaseOrder).filter(models.PurchaseOrder.id == uuid.UUID(po_id)).first()
    if po:
        po.status = 'sent'
        po.approved_by = uuid.UUID(session['user_id'])
        db.commit()
        flash(f'PO {po.po_number} approved and sent.', 'success')
    close_db(db)
    return redirect(url_for('purchase_orders'))

@app.route('/purchase-orders/<po_id>/cancel', methods=['POST'])
@login_required
def cancel_po(po_id):
    db = get_db()
    po = db.query(models.PurchaseOrder).filter(models.PurchaseOrder.id == uuid.UUID(po_id)).first()
    if po:
        po.status = 'cancelled'
        db.commit()
        flash(f'PO {po.po_number} cancelled.', 'info')
    close_db(db)
    return redirect(url_for('purchase_orders'))

# ─── BOQ ──────────────────────────────────────────────────────────────────────

@app.route('/boq')
@login_required
def boq():
    db = get_db()
    projects = db.query(models.Project).filter(models.Project.status == 'active').all()
    materials = db.query(models.Material).order_by(models.Material.name).all()
    selected_id = request.args.get('project_id')
    boq_data = []
    selected_project = None

    if selected_id:
        selected_project = db.query(models.Project).filter(models.Project.id == uuid.UUID(selected_id)).first()
        boq_items = db.query(models.BOQItem).filter(models.BOQItem.project_id == uuid.UUID(selected_id)).all()
        for item in boq_items:
            actual = db.query(func.sum(models.StockLedger.quantity)).filter(
                models.StockLedger.project_id == uuid.UUID(selected_id),
                models.StockLedger.material_id == item.material_id,
                models.StockLedger.movement_type.in_(['outward', 'wastage'])
            ).scalar() or 0
            planned = float(item.planned_quantity)
            actual_f = float(actual)
            variance = actual_f - planned
            variance_pct = (variance / planned * 100) if planned > 0 else 0
            boq_data.append({
                'id': str(item.id),
                'material': item.material.name if item.material else 'Unknown',
                'unit': item.material.unit if item.material else '',
                'planned': planned,
                'actual': actual_f,
                'variance': round(variance, 2),
                'variance_pct': round(variance_pct, 1),
                'over_budget': variance > 0,
            })

    close_db(db)
    return render_template('boq.html',
        projects=projects, materials=materials,
        selected_project=selected_project, boq_data=boq_data,
        selected_id=selected_id,
    )

@app.route('/boq/add', methods=['POST'])
@login_required
def add_boq():
    db = get_db()
    project_id = uuid.UUID(request.form['project_id'])
    material_id = uuid.UUID(request.form['material_id'])
    planned_qty = float(request.form['planned_quantity'])

    existing = db.query(models.BOQItem).filter(
        models.BOQItem.project_id == project_id,
        models.BOQItem.material_id == material_id
    ).first()
    if existing:
        existing.planned_quantity = planned_qty
        existing.description = request.form.get('description')
    else:
        item = models.BOQItem(
            project_id=project_id, material_id=material_id,
            planned_quantity=planned_qty, description=request.form.get('description')
        )
        db.add(item)
    db.commit()
    close_db(db)
    flash('BOQ item saved.', 'success')
    return redirect(url_for('boq', project_id=str(project_id)))

# ─── Stock Ledger ──────────────────────────────────────────────────────────────

@app.route('/stock-ledger')
@login_required
def stock_ledger():
    db = get_db()
    projects = db.query(models.Project).filter(models.Project.status == 'active').all()
    materials = db.query(models.Material).order_by(models.Material.name).all()
    selected_id = request.args.get('project_id')
    ledger = []
    inventory = []
    selected_project = None

    if selected_id:
        selected_project = db.query(models.Project).filter(models.Project.id == uuid.UUID(selected_id)).first()
        ledger = db.query(models.StockLedger).filter(
            models.StockLedger.project_id == uuid.UUID(selected_id)
        ).order_by(models.StockLedger.created_at.desc()).limit(100).all()
        inventory = db.query(models.ProjectInventory).filter(
            models.ProjectInventory.project_id == uuid.UUID(selected_id)
        ).all()

    close_db(db)
    return render_template('stock_ledger.html',
        projects=projects, materials=materials,
        selected_project=selected_project, ledger=ledger,
        inventory=inventory, selected_id=selected_id,
    )

# ─── Transfers ────────────────────────────────────────────────────────────────

@app.route('/transfers')
@login_required
def transfers():
    db = get_db()
    projects = db.query(models.Project).filter(models.Project.status == 'active').all()
    materials = db.query(models.Material).order_by(models.Material.name).all()
    all_transfers = db.query(models.TransferNote).order_by(models.TransferNote.created_at.desc()).all()
    close_db(db)
    return render_template('transfers.html', projects=projects, materials=materials, transfers=all_transfers)

@app.route('/transfers/create', methods=['POST'])
@login_required
def create_transfer():
    db = get_db()
    t = models.TransferNote(
        from_project_id=uuid.UUID(request.form['from_project_id']),
        to_project_id=uuid.UUID(request.form['to_project_id']),
        material_id=uuid.UUID(request.form['material_id']),
        quantity=float(request.form['quantity']),
        remarks=request.form.get('remarks'),
        raised_by=uuid.UUID(session['user_id']),
        status='pending',
    )
    db.add(t)
    db.commit()
    close_db(db)
    flash('Transfer note created.', 'success')
    return redirect(url_for('transfers'))

@app.route('/transfers/<transfer_id>/receive', methods=['POST'])
@login_required
def receive_transfer(transfer_id):
    db = get_db()
    t = db.query(models.TransferNote).filter(models.TransferNote.id == uuid.UUID(transfer_id)).first()
    if t and t.status != 'received':
        t.status = 'received'
        # Deduct from source
        _log_stock(db, t.from_project_id, t.material_id, 'transfer_out', float(t.quantity))
        # Add to destination
        _log_stock(db, t.to_project_id, t.material_id, 'transfer_in', float(t.quantity))
        db.commit()
        flash('Transfer confirmed and stock updated.', 'success')
    close_db(db)
    return redirect(url_for('transfers'))

# ─── Waste Logs ───────────────────────────────────────────────────────────────

@app.route('/waste-logs')
@login_required
def waste_logs():
    db = get_db()
    projects = db.query(models.Project).filter(models.Project.status == 'active').all()
    materials = db.query(models.Material).order_by(models.Material.name).all()
    logs = db.query(models.WasteLog).order_by(models.WasteLog.created_at.desc()).all()
    close_db(db)
    return render_template('waste_logs.html', projects=projects, materials=materials, logs=logs)

@app.route('/waste-logs/add', methods=['POST'])
@login_required
def add_waste():
    db = get_db()
    w = models.WasteLog(
        project_id=uuid.UUID(request.form['project_id']),
        material_id=uuid.UUID(request.form['material_id']),
        quantity=float(request.form['quantity']),
        reason=request.form.get('reason'),
        logged_by=uuid.UUID(session['user_id']),
        entry_date=date.today(),
    )
    db.add(w)
    # Deduct from inventory
    _log_stock(db, w.project_id, w.material_id, 'wastage', float(w.quantity))
    db.commit()
    close_db(db)
    flash('Waste log recorded.', 'success')
    return redirect(url_for('waste_logs'))

# ─── Helpers ──────────────────────────────────────────────────────────────────

def _log_stock(db, project_id, material_id, movement_type, quantity):
    entry = models.StockLedger(
        project_id=project_id, material_id=material_id,
        movement_type=movement_type, quantity=quantity,
        entry_date=date.today(), logged_by=uuid.UUID(session.get('user_id', str(uuid.uuid4()))),
    )
    db.add(entry)
    # Update inventory
    inv = db.query(models.ProjectInventory).filter(
        models.ProjectInventory.project_id == project_id,
        models.ProjectInventory.material_id == material_id,
    ).first()
    sign = 1 if movement_type in ('inward', 'transfer_in') else -1
    if inv:
        inv.current_quantity = float(inv.current_quantity) + sign * quantity
    else:
        db.add(models.ProjectInventory(project_id=project_id, material_id=material_id, current_quantity=sign * quantity))

if __name__ == '__main__':
    app.run(debug=True, port=5050)
