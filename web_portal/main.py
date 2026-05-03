import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from flask import Flask, render_template, request, redirect, url_for, session, flash, jsonify, send_from_directory
from sqlalchemy import func
from app.database import SessionLocal
from app import models
import bcrypt
from datetime import date, datetime
import uuid

app = Flask(__name__)
app.secret_key = os.urandom(24)

@app.route('/uploads/<path:filename>')
def uploaded_file(filename):
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    return send_from_directory(os.path.join(root_dir, 'uploads'), filename)

# ─── DB Helpers ───────────────────────────────────────────────────────────────
def get_db():
    return SessionLocal()

def close_db(db):
    db.close()

def get_authorized_projects(db, org_id, user_id, user_role):
    if user_role == 'owner' or user_role == 'material_manager':
        return db.query(models.Project).filter(
            models.Project.organization_id == org_id,
            models.Project.status == 'active'
        ).order_by(models.Project.created_at.desc()).all()
    else:
        # Supervisor role - only assigned projects
        return db.query(models.Project).join(models.ProjectUser).filter(
            models.Project.organization_id == org_id,
            models.Project.status == 'active',
            models.ProjectUser.user_id == uuid.UUID(user_id)
        ).order_by(models.Project.created_at.desc()).all()

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
            if user.role not in ('owner', 'supervisor', 'material_manager'):
                flash('Access denied. This portal is for Owners and Supervisors only.', 'error')
                return redirect(url_for('login'))
            session['user_id'] = str(user.id)
            session['user_role'] = user.role
            session['user_name'] = user.name
            session['organization_id'] = str(user.organization_id)
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
    org_id = uuid.UUID(session['organization_id'])
    user_id = session['user_id']
    user_role = session['user_role']
    
    # Authorized project IDs for filtering
    auth_projects = get_authorized_projects(db, org_id, user_id, user_role)
    auth_ids = [p.id for p in auth_projects]
    
    # Base queries
    po_query = db.query(models.PurchaseOrder).filter(models.PurchaseOrder.organization_id == org_id)
    transfer_query = db.query(models.TransferNote).join(models.Project, models.TransferNote.to_project_id == models.Project.id).filter(models.Project.organization_id == org_id)
    waste_query = db.query(func.sum(models.WasteLog.quantity)).join(models.Project, models.WasteLog.project_id == models.Project.id).filter(models.Project.organization_id == org_id)
    inventory_query = db.query(models.ProjectInventory).join(models.Project, models.ProjectInventory.project_id == models.Project.id).filter(models.Project.organization_id == org_id)
    req_query = db.query(models.MaterialRequest).join(models.Project, models.MaterialRequest.project_id == models.Project.id).filter(models.Project.organization_id == org_id)

    if user_role == 'supervisor':
        po_query = po_query.filter(models.PurchaseOrder.project_id.in_(auth_ids))
        transfer_query = transfer_query.filter(models.TransferNote.to_project_id.in_(auth_ids))
        waste_query = waste_query.filter(models.WasteLog.project_id.in_(auth_ids))
        inventory_query = inventory_query.filter(models.ProjectInventory.project_id.in_(auth_ids))
        req_query = req_query.filter(models.MaterialRequest.project_id.in_(auth_ids))

    pending_pos = po_query.filter(models.PurchaseOrder.status == 'draft').count()
    active_vendors = db.query(models.Vendor).filter(models.Vendor.organization_id == org_id, models.Vendor.is_active == True).count()
    total_materials = db.query(models.Material).filter(models.Material.organization_id == org_id).count()
    pending_transfers = transfer_query.filter(models.TransferNote.status == 'pending').count()
    total_waste = waste_query.scalar() or 0
    recent_pos = po_query.order_by(models.PurchaseOrder.created_at.desc()).limit(5).all()
    pending_requests = req_query.filter(models.MaterialRequest.status == 'pending').count()

    # Low stock alerts: Check both current inventory AND BOQ requirements
    low_stock = []
    # 1. Fetch BOQ items first to build requirement set and overrides
    boq_items = db.query(models.BOQItem).join(
        models.Project, models.BOQItem.project_id == models.Project.id
    ).filter(
        models.Project.id.in_(auth_ids)
    ).all()
    
    # Store BOQ requirements: {(project_id, material_id): min_stock_level}
    boq_map = {(b.project_id, b.material_id): float(b.min_stock_level or 0) for b in boq_items}
    # Store BOQ names for alerts: {(project_id, material_id): (proj_name, mat_name, unit)}
    boq_names = {(b.project_id, b.material_id): (b.project.name, b.material.name, b.material.unit) for b in boq_items}

    # 2. Start with actual inventory records
    inventory = inventory_query.all()
    tracked_pairs = set() # (project_id, material_id)
    
    for item in inventory:
        mat = item.material
        proj = item.project if hasattr(item, 'project') else db.query(models.Project).filter(models.Project.id == item.project_id).first()
        if not mat or not proj: continue
        
        pair = (proj.id, mat.id)
        tracked_pairs.add(pair)
        
        current_qty = float(item.current_quantity)
        # Use BOQ min stock as override, fallback to Material default
        min_qty = boq_map.get(pair, float(mat.min_stock_level or 0))
        
        # ALERT IF: Below threshold OR (is in BOQ and is zero)
        is_required = pair in boq_map
        if current_qty < min_qty or (current_qty == 0 and is_required):
            reason = 'Critical: Zero Stock (Required by BOQ)' if current_qty == 0 and is_required else 'Below Min Stock'
            low_stock.append({
                'project': proj.name,
                'material': mat.name,
                'unit': mat.unit,
                'current': current_qty,
                'min': min_qty,
                'reason': reason
            })

    # 3. Check BOQ items for materials NOT EVEN in inventory table
    for pair, (proj_name, mat_name, mat_unit) in boq_names.items():
        if pair not in tracked_pairs:
            low_stock.append({
                'project': proj_name,
                'material': mat_name,
                'unit': mat_unit,
                'current': 0.0,
                'min': boq_map[pair],
                'reason': 'Critical: Missing from Stock (In BOQ)'
            })

    rendered = render_template('dashboard.html',
        pending_pos=pending_pos,
        active_vendors=active_vendors,
        total_materials=total_materials,
        pending_transfers=pending_transfers,
        pending_requests=pending_requests,
        total_waste=float(total_waste),
        recent_pos=recent_pos,
        low_stock=low_stock,
    )
    close_db(db)
    return rendered

# ─── Vendors ──────────────────────────────────────────────────────────────────
@app.route('/vendors')
@login_required
def vendors():
    db = get_db()
    org_id = uuid.UUID(session['organization_id'])
    all_vendors = db.query(models.Vendor).filter(models.Vendor.organization_id == org_id).order_by(models.Vendor.name).all()
    materials = db.query(models.Material).filter(models.Material.organization_id == org_id).order_by(models.Material.name).all()
    
    # Handle inline price comparison
    selected_material_id = request.args.get('compare_material_id')
    comparison_prices = []
    selected_material = None
    if selected_material_id:
        selected_material = db.query(models.Material).filter(models.Material.id == uuid.UUID(selected_material_id)).first()
        comparison_prices = db.query(models.VendorPrice).filter(
            models.VendorPrice.material_id == uuid.UUID(selected_material_id)
        ).order_by(models.VendorPrice.price_per_unit).all()

    rendered = render_template('vendors.html', 
                               vendors=all_vendors, 
                               materials=materials, 
                               comparison_prices=comparison_prices,
                               selected_material=selected_material)
    close_db(db)
    return rendered

@app.route('/vendors/add', methods=['POST'])
@login_required
def add_vendor():
    db = get_db()
    v = models.Vendor(
        organization_id=uuid.UUID(session['organization_id']),
        name=request.form['name'],
        phone=request.form.get('phone'),
        email=request.form.get('email'),
        address=request.form.get('address'),
        gstin=request.form.get('gstin'),
    )
    db.add(v)
    db.commit()
    vendor_name = v.name
    close_db(db)
    flash(f'Vendor "{vendor_name}" added successfully.', 'success')
    return redirect(url_for('vendors'))

@app.route('/vendors/<vendor_id>/deactivate', methods=['POST'])
@login_required
def deactivate_vendor(vendor_id):
    db = get_db()
    v = db.query(models.Vendor).filter(
        models.Vendor.id == uuid.UUID(vendor_id),
        models.Vendor.organization_id == uuid.UUID(session['organization_id'])
    ).first()
    if v:
        v.is_active = False
        vendor_name = v.name
        db.commit()
        flash(f'Vendor "{vendor_name}" deactivated.', 'info')
    close_db(db)
    return redirect(url_for('vendors'))

# ─── Materials ────────────────────────────────────────────────────────────────
@app.route('/materials')
@login_required
def materials_page():
    db = get_db()
    org_id = uuid.UUID(session['organization_id'])
    mats = db.query(models.Material).filter(models.Material.organization_id == org_id).order_by(models.Material.name).all()
    rendered = render_template('materials.html', materials=mats)
    close_db(db)
    return rendered

@app.route('/materials/add', methods=['POST'])
@login_required
def add_material_web():
    db = get_db()
    mat = models.Material(
        organization_id=uuid.UUID(session['organization_id']),
        name=request.form['name'],
        unit=request.form['unit'],
        category=request.form.get('category'),
        min_stock_level=float(request.form.get('min_stock_level') or 0),
    )
    db.add(mat)
    db.commit()
    mat_name = mat.name
    close_db(db)
    flash(f'Material "{mat_name}" added.', 'success')
    return redirect(url_for('materials_page'))

# ─── Projects ─────────────────────────────────────────────────────────────────
@app.route('/projects')
@login_required
def projects_page():
    db = get_db()
    org_id = uuid.UUID(session['organization_id'])
    projs = db.query(models.Project).filter(models.Project.organization_id == org_id).order_by(models.Project.name).all()
    rendered = render_template('projects.html', projects=projs)
    close_db(db)
    return rendered

@app.route('/projects/add', methods=['POST'])
@login_required
def add_project_web():
    db = get_db()
    proj = models.Project(
        organization_id=uuid.UUID(session['organization_id']),
        name=request.form['name'],
        code=request.form.get('code'),
        status='active'
    )
    db.add(proj)
    db.commit()
    proj_name = proj.name
    close_db(db)
    flash(f'Project/Site "{proj_name}" added.', 'success')
    return redirect(url_for('projects_page'))

# ─── Vendor Prices ──────────────────────────────────────────────────
@app.route('/vendor-prices/add', methods=['POST'])
@login_required
def add_vendor_price():
    db = get_db()
    v_id = uuid.UUID(request.form['vendor_id'])
    m_id = uuid.UUID(request.form['material_id'])
    price_val = float(request.form['price_per_unit'])
    notes = request.form.get('notes')
    
    # Upsert Logic: Check if price already exists for this vendor + material
    existing = db.query(models.VendorPrice).filter(
        models.VendorPrice.vendor_id == v_id,
        models.VendorPrice.material_id == m_id
    ).first()
    
    if existing:
        existing.price_per_unit = price_val
        existing.notes = notes
        existing.effective_date = date.today()
        flash('Price updated for existing material.', 'info')
    else:
        price = models.VendorPrice(
            vendor_id=v_id,
            material_id=m_id,
            price_per_unit=price_val,
            notes=notes,
            effective_date=date.today()
        )
        db.add(price)
        flash('New price added.', 'success')
        
    db.commit()
    close_db(db)
    return redirect(url_for('vendors'))

@app.route('/vendor-prices/<price_id>/delete', methods=['POST'])
@login_required
def delete_vendor_price(price_id):
    db = get_db()
    price = db.query(models.VendorPrice).filter(models.VendorPrice.id == uuid.UUID(price_id)).first()
    if price:
        # Verify vendor belongs to org
        vendor = db.query(models.Vendor).filter(
            models.Vendor.id == price.vendor_id,
            models.Vendor.organization_id == uuid.UUID(session['organization_id'])
        ).first()
        if vendor:
            db.delete(price)
            db.commit()
            flash('Price removed.', 'info')
    close_db(db)
    return redirect(url_for('vendors'))

@app.route('/vendors/<vendor_id>')
@login_required
def vendor_detail(vendor_id):
    db = get_db()
    org_id = uuid.UUID(session['organization_id'])
    vendor = db.query(models.Vendor).filter(
        models.Vendor.id == uuid.UUID(vendor_id),
        models.Vendor.organization_id == org_id
    ).first()
    if not vendor:
        close_db(db)
        flash('Vendor not found.', 'error')
        return redirect(url_for('vendors'))
    
    # Get all prices for this vendor
    prices = db.query(models.VendorPrice).filter(
        models.VendorPrice.vendor_id == vendor.id
    ).all()
    
    rendered = render_template('vendor_detail.html', vendor=vendor, prices=prices)
    close_db(db)
    return rendered

@app.route('/vendor-prices/<material_id>')
@login_required
def vendor_prices_view(material_id):
    db = get_db()
    prices = db.query(models.VendorPrice).filter(
        models.VendorPrice.material_id == uuid.UUID(material_id)
    ).order_by(models.VendorPrice.price_per_unit).all()
    mat = db.query(models.Material).filter(
        models.Material.id == uuid.UUID(material_id),
        models.Material.organization_id == uuid.UUID(session['organization_id'])
    ).first()
    rendered = render_template('vendor_prices.html', prices=prices, material=mat)
    close_db(db)
    return rendered

# ─── Purchase Orders ──────────────────────────────────────────────────────────
@app.route('/purchase-orders')
@login_required
def purchase_orders():
    db = get_db()
    org_id = uuid.UUID(session['organization_id'])
    pos = db.query(models.PurchaseOrder).filter(models.PurchaseOrder.organization_id == org_id).order_by(models.PurchaseOrder.created_at.desc()).all()
    vendors = db.query(models.Vendor).filter(models.Vendor.organization_id == org_id, models.Vendor.is_active == True).all()
    projects = db.query(models.Project).filter(models.Project.organization_id == org_id, models.Project.status == 'active').all()
    materials = db.query(models.Material).filter(models.Material.organization_id == org_id).order_by(models.Material.name).all()
    rendered = render_template('purchase_orders.html', pos=pos, vendors=vendors, projects=projects, materials=materials)
    close_db(db)
    return rendered

@app.route('/purchase-orders/create', methods=['POST'])
@login_required
def create_po():
    import random
    db = get_db()
    org_id = uuid.UUID(session['organization_id'])
    po_number = f"PO-{date.today().strftime('%Y%m')}-{random.randint(1000,9999)}"
    po = models.PurchaseOrder(
        organization_id=org_id,
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
    po_num = po.po_number
    db.commit()
    close_db(db)
    flash(f'Purchase Order {po_num} created.', 'success')
    return redirect(url_for('purchase_orders'))

@app.route('/purchase-orders/<po_id>/approve', methods=['POST'])
@login_required
def approve_po(po_id):
    db = get_db()
    po = db.query(models.PurchaseOrder).filter(
        models.PurchaseOrder.id == uuid.UUID(po_id),
        models.PurchaseOrder.organization_id == uuid.UUID(session['organization_id'])
    ).first()
    if po:
        po.status = 'sent'
        po.approved_by = uuid.UUID(session['user_id'])
        po_num = po.po_number
        db.commit()
        flash(f'PO {po_num} approved and sent.', 'success')
    close_db(db)
    return redirect(url_for('purchase_orders'))

@app.route('/purchase-orders/<po_id>/cancel', methods=['POST'])
@login_required
def cancel_po(po_id):
    db = get_db()
    po = db.query(models.PurchaseOrder).filter(
        models.PurchaseOrder.id == uuid.UUID(po_id),
        models.PurchaseOrder.organization_id == uuid.UUID(session['organization_id'])
    ).first()
    if po:
        po.status = 'cancelled'
        po_num = po.po_number
        db.commit()
        flash(f'PO {po_num} cancelled.', 'info')
    close_db(db)
    return redirect(url_for('purchase_orders'))

# ─── BOQ ──────────────────────────────────────────────────────────────────────
@app.route('/boq')
@login_required
def boq():
    db = get_db()
    org_id = uuid.UUID(session['organization_id'])
    user_id = session['user_id']
    user_role = session['user_role']
    
    # Use helper for authorized projects
    projects = get_authorized_projects(db, org_id, user_id, user_role)
    materials = db.query(models.Material).filter(models.Material.organization_id == org_id).order_by(models.Material.name).all()
    
    selected_id = request.args.get('project_id')
    # Auto-select latest project if none selected
    if not selected_id and projects:
        selected_id = str(projects[0].id)
        
    boq_data = []
    selected_project = None

    if selected_id:
        selected_project = db.query(models.Project).filter(
            models.Project.id == uuid.UUID(selected_id),
            models.Project.organization_id == org_id
        ).first()
        if selected_project:
            from app import crud
            boq_data = crud.get_boq_with_actuals(db, selected_project.id)

    rendered = render_template('boq.html',
        projects=projects, materials=materials,
        selected_project=selected_project, boq_data=boq_data,
        selected_id=selected_id,
    )
    close_db(db)
    return rendered

@app.route('/boq/add', methods=['POST'])
@login_required
def add_boq():
    db = get_db()
    project_id = uuid.UUID(request.form['project_id'])
    material_id = uuid.UUID(request.form['material_id'])
    planned_qty = float(request.form['planned_quantity'])
    unit_price = float(request.form.get('estimated_unit_price') or 0)

    # Verify project belongs to org
    proj = db.query(models.Project).filter(
        models.Project.id == project_id,
        models.Project.organization_id == uuid.UUID(session['organization_id'])
    ).first()
    if not proj:
        close_db(db)
        flash('Project not found.', 'error')
        return redirect(url_for('boq'))

    min_stock = float(request.form.get('min_stock_level') or 0)
    description = request.form.get('description')

    from app import schemas, crud
    boq_item = schemas.BOQItemCreate(
        project_id=project_id,
        material_id=material_id,
        planned_quantity=planned_qty,
        estimated_unit_price=unit_price,
        min_stock_level=min_stock,
        description=description
    )
    crud.upsert_boq_item(db, boq_item)
    db.commit()
    close_db(db)
    flash('BOQ item saved.', 'success')
    return redirect(url_for('boq', project_id=str(project_id)))

# ─── Stock Ledger ──────────────────────────────────────────────────────────────
@app.route('/stock-ledger')
@login_required
def stock_ledger():
    db = get_db()
    org_id = uuid.UUID(session['organization_id'])
    user_id = session['user_id']
    user_role = session['user_role']
    
    # Use helper for authorized projects
    projects = get_authorized_projects(db, org_id, user_id, user_role)
    materials = db.query(models.Material).filter(models.Material.organization_id == org_id).order_by(models.Material.name).all()
    
    selected_id = request.args.get('project_id')
    # Auto-select latest project if none selected
    if not selected_id and projects:
        selected_id = str(projects[0].id)
        
    ledger = []
    inventory = []
    selected_project = None

    if selected_id:
        selected_project = db.query(models.Project).filter(
            models.Project.id == uuid.UUID(selected_id),
            models.Project.organization_id == org_id
        ).first()
        if selected_project:
            ledger = db.query(models.StockLedger).filter(
                models.StockLedger.project_id == selected_project.id
            ).order_by(models.StockLedger.created_at.desc()).limit(100).all()
            inventory = db.query(models.ProjectInventory).filter(
                models.ProjectInventory.project_id == selected_project.id
            ).all()

    rendered = render_template('stock_ledger.html',
        projects=projects, materials=materials,
        selected_project=selected_project, ledger=ledger,
        inventory=inventory, selected_id=selected_id,
    )
    close_db(db)
    return rendered

@app.route('/stock/receive', methods=['POST'])
@login_required
def receive_material_web():
    db = get_db()
    project_id = uuid.UUID(request.form['project_id'])
    material_id = uuid.UUID(request.form['material_id'])
    qty = float(request.form['quantity'])
    
    # Verify project
    proj = db.query(models.Project).filter(models.Project.id == project_id, models.Project.organization_id == uuid.UUID(session['organization_id'])).first()
    if proj:
        _log_stock(db, project_id, material_id, 'inward', qty)
        db.commit()
        flash('Material receipt logged. Stock increased.', 'success')
    close_db(db)
    return redirect(url_for('stock_ledger', project_id=str(project_id)))

@app.route('/stock/consume', methods=['POST'])
@login_required
def consume_stock():
    db = get_db()
    project_id = uuid.UUID(request.form['project_id'])
    material_id = uuid.UUID(request.form['material_id'])
    qty = float(request.form['quantity'])
    
    # Verify project
    proj = db.query(models.Project).filter(models.Project.id == project_id, models.Project.organization_id == uuid.UUID(session['organization_id'])).first()
    if proj:
        _log_stock(db, project_id, material_id, 'consumption', qty)
        db.commit()
        flash('Consumption logged. Stock updated.', 'success')
    close_db(db)
    return redirect(url_for('stock_ledger', project_id=str(project_id)))

@app.route('/stock/adjust', methods=['POST'])
@login_required
def adjust_stock():
    db = get_db()
    project_id = uuid.UUID(request.form['project_id'])
    material_id = uuid.UUID(request.form['material_id'])
    qty = float(request.form['quantity'])
    adj_type = request.form['type'] # 'add' or 'remove'
    
    proj = db.query(models.Project).filter(models.Project.id == project_id, models.Project.organization_id == uuid.UUID(session['organization_id'])).first()
    if proj:
        move_type = 'adjustment_in' if adj_type == 'add' else 'adjustment_out'
        _log_stock(db, project_id, material_id, move_type, qty)
        db.commit()
        flash('Inventory adjusted.', 'info')
    close_db(db)
    return redirect(url_for('stock_ledger', project_id=str(project_id)))

# ─── Transfers ────────────────────────────────────────────────────────────────
@app.route('/transfers')
@login_required
def transfers():
    db = get_db()
    org_id = uuid.UUID(session['organization_id'])
    projects = db.query(models.Project).filter(models.Project.organization_id == org_id, models.Project.status == 'active').all()
    materials = db.query(models.Material).filter(models.Material.organization_id == org_id).order_by(models.Material.name).all()
    # Only show transfers where destination project belongs to this org
    all_transfers = db.query(models.TransferNote).join(
        models.Project, models.TransferNote.to_project_id == models.Project.id
    ).filter(
        models.Project.organization_id == org_id
    ).order_by(models.TransferNote.created_at.desc()).all()
    rendered = render_template('transfers.html', projects=projects, materials=materials, transfers=all_transfers)
    close_db(db)
    return rendered

@app.route('/transfers/create', methods=['POST'])
@login_required
def create_transfer():
    db = get_db()
    org_id = uuid.UUID(session['organization_id'])
    from_id = uuid.UUID(request.form['from_project_id'])
    to_id = uuid.UUID(request.form['to_project_id'])
    mat_id = uuid.UUID(request.form['material_id'])
    qty = float(request.form['quantity'])
    
    # 1. Verify projects belong to org
    from_proj = db.query(models.Project).filter(models.Project.id == from_id, models.Project.organization_id == org_id).first()
    to_proj = db.query(models.Project).filter(models.Project.id == to_id, models.Project.organization_id == org_id).first()
    
    if not from_proj or not to_proj:
        close_db(db)
        flash('One or more projects not found.', 'error')
        return redirect(url_for('transfers'))

    if from_id == to_id:
        close_db(db)
        flash('Source and destination cannot be the same.', 'error')
        return redirect(url_for('transfers'))

    # 2. CHECK STOCK: Verify source project has enough stock
    inv = db.query(models.ProjectInventory).filter(
        models.ProjectInventory.project_id == from_id,
        models.ProjectInventory.material_id == mat_id
    ).first()
    
    current_qty = float(inv.current_quantity) if inv else 0
    if current_qty < qty:
        mat = db.query(models.Material).filter(models.Material.id == mat_id).first()
        close_db(db)
        flash(f'Insufficient stock! {from_proj.name} only has {current_qty} {mat.unit if mat else ""} available.', 'error')
        return redirect(url_for('transfers'))

    # 3. Create transfer
    t = models.TransferNote(
        from_project_id=from_id,
        to_project_id=to_id,
        material_id=mat_id,
        quantity=qty,
        remarks=request.form.get('remarks'),
        raised_by=uuid.UUID(session['user_id']),
        status='pending',
    )
    db.add(t)
    db.commit()
    close_db(db)
    flash('Transfer note created and pending delivery.', 'success')
    return redirect(url_for('transfers'))

@app.route('/transfers/<transfer_id>/receive', methods=['POST'])
@login_required
def receive_transfer(transfer_id):
    db = get_db()
    t = db.query(models.TransferNote).filter(models.TransferNote.id == uuid.UUID(transfer_id)).first()
    # Check if destination project belongs to org
    if t:
        to_proj = db.query(models.Project).filter(models.Project.id == t.to_project_id, models.Project.organization_id == uuid.UUID(session['organization_id'])).first()
        if to_proj and t.status != 'received':
            t.status = 'received'
            _log_stock(db, t.from_project_id, t.material_id, 'transfer_out', float(t.quantity))
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
    org_id = uuid.UUID(session['organization_id'])
    projects = db.query(models.Project).filter(models.Project.organization_id == org_id, models.Project.status == 'active').all()
    materials = db.query(models.Material).filter(models.Material.organization_id == org_id).order_by(models.Material.name).all()
    logs = db.query(models.WasteLog).join(
        models.Project, models.WasteLog.project_id == models.Project.id
    ).filter(
        models.Project.organization_id == org_id
    ).order_by(models.WasteLog.created_at.desc()).all()
    rendered = render_template('waste_logs.html', projects=projects, materials=materials, logs=logs)
    close_db(db)
    return rendered

@app.route('/waste-logs/add', methods=['POST'])
@login_required
def add_waste():
    db = get_db()
    project_id = uuid.UUID(request.form['project_id'])
    # Verify project belongs to org
    proj = db.query(models.Project).filter(models.Project.id == project_id, models.Project.organization_id == uuid.UUID(session['organization_id'])).first()
    if not proj:
        close_db(db)
        flash('Project not found.', 'error')
        return redirect(url_for('waste_logs'))

    w = models.WasteLog(
        project_id=project_id,
        material_id=uuid.UUID(request.form['material_id']),
        quantity=float(request.form['quantity']),
        reason=request.form.get('reason'),
        logged_by=uuid.UUID(session['user_id']),
        entry_date=date.today(),
    )
    db.add(w)
    _log_stock(db, w.project_id, w.material_id, 'wastage', float(w.quantity))
    db.commit()
    close_db(db)
    flash('Waste log recorded.', 'success')
    return redirect(url_for('waste_logs'))

# ─── Material Requests ────────────────────────────────────────────────────────
@app.route('/requests')
@login_required
def material_requests():
    db = get_db()
    org_id = uuid.UUID(session['organization_id'])
    # Get requests for projects in this org
    requests = db.query(models.MaterialRequest).join(
        models.Project, models.MaterialRequest.project_id == models.Project.id
    ).filter(
        models.Project.organization_id == org_id
    ).order_by(models.MaterialRequest.created_at.desc()).all()
    rendered = render_template('material_requests.html', requests=requests)
    close_db(db)
    return rendered

@app.route('/requests/<request_id>/approve', methods=['POST'])
@login_required
def approve_request(request_id):
    db = get_db()
    req = db.query(models.MaterialRequest).filter(models.MaterialRequest.id == uuid.UUID(request_id)).first()
    if req:
        # Verify org
        proj = db.query(models.Project).filter(models.Project.id == req.project_id, models.Project.organization_id == uuid.UUID(session['organization_id'])).first()
        if proj:
            req.status = 'approved'
            db.commit()
            flash('Material request approved.', 'success')
    close_db(db)
    return redirect(url_for('material_requests'))

@app.route('/requests/<request_id>/reject', methods=['POST'])
@login_required
def reject_request(request_id):
    db = get_db()
    req = db.query(models.MaterialRequest).filter(models.MaterialRequest.id == uuid.UUID(request_id)).first()
    if req:
        proj = db.query(models.Project).filter(models.Project.id == req.project_id, models.Project.organization_id == uuid.UUID(session['organization_id'])).first()
        if proj:
            req.status = 'rejected'
            db.commit()
            flash('Material request rejected.', 'info')
    close_db(db)
    return redirect(url_for('material_requests'))

# ─── Helpers ──────────────────────────────────────────────────────────────────
def _log_stock(db, project_id, material_id, movement_type, quantity):
    entry = models.StockLedger(
        project_id=project_id, material_id=material_id,
        movement_type=movement_type, quantity=quantity,
        entry_date=date.today(), logged_by=uuid.UUID(session.get('user_id', str(uuid.uuid4()))),
    )
    db.add(entry)
    inv = db.query(models.ProjectInventory).filter(
        models.ProjectInventory.project_id == project_id,
        models.ProjectInventory.material_id == material_id,
    ).first()
    sign = 1 if movement_type in ('inward', 'transfer_in', 'adjustment_in') else -1
    if inv:
        inv.current_quantity = float(inv.current_quantity) + sign * quantity
    else:
        db.add(models.ProjectInventory(project_id=project_id, material_id=material_id, current_quantity=sign * quantity))

# ─── Attendance ───────────────────────────────────────────────────────────────
@app.route('/attendance')
@login_required
def attendance():
    db = get_db()
    org_id = uuid.UUID(session['organization_id'])
    user_id = session['user_id']
    user_role = session['user_role']
    
    projects = get_authorized_projects(db, org_id, user_id, user_role)
    project_id = request.args.get('project_id')
    entry_date_str = request.args.get('date', date.today().isoformat())
    entry_date = date.fromisoformat(entry_date_str)

    summary = []
    daily_photos = []
    
    if project_id:
        proj_id = uuid.UUID(project_id)
        # Get daily summary for this project and date
        attendance_records = db.query(
            models.Worker.name,
            models.Worker.daily_rate,
            models.Attendance.status,
            models.Gang.name.label("gang_name")
        ).join(
            models.Attendance, models.Worker.id == models.Attendance.worker_id
        ).outerjoin(
            models.Gang, models.Worker.gang_id == models.Gang.id
        ).filter(
            models.Attendance.project_id == proj_id,
            models.Attendance.entry_date == entry_date
        ).all()
        
        summary = [
            {
                "worker_name": r.name,
                "rate": float(r.daily_rate or 0),
                "status": r.status,
                "gang": r.gang_name,
                "cost": float(r.daily_rate or 0) * (1.0 if r.status == 'present' else 0.5 if r.status == 'half_day' else 0.0)
            } for r in attendance_records
        ]
        
        # Get photos with gang names for this project/date
        daily_photos_raw = db.query(
            models.AttendancePhoto.photo_url,
            models.AttendancePhoto.uploaded_at,
            models.Gang.name.label("gang_name")
        ).join(models.Gang).filter(
            models.Gang.project_id == proj_id,
            models.AttendancePhoto.entry_date == entry_date
        ).all()
        
        daily_photos = [
            {
                "url": p.photo_url,
                "gang_name": p.gang_name,
                "time": p.uploaded_at
            } for p in daily_photos_raw
        ]

    close_db(db)
    return render_template('attendance.html', 
                         projects=projects, 
                         selected_project_id=project_id,
                         selected_date=entry_date_str,
                         summary=summary,
                         photos=daily_photos)

# ─── Documents ───────────────────────────────────────────────────────────────
@app.route('/documents', methods=['GET', 'POST'])
@login_required
def documents():
    db = get_db()
    org_id = uuid.UUID(session['organization_id'])
    user_id = session['user_id']
    user_role = session['user_role']
    
    projects = get_authorized_projects(db, org_id, user_id, user_role)
    project_id = request.args.get('project_id')
    
    if request.method == 'POST':
        proj_id_form = request.form.get('project_id')
        title = request.form.get('title')
        category = request.form.get('category')
        file = request.files.get('file')
        
        if file and proj_id_form:
            upload_dir = f"uploads/documents/{proj_id_form}"
            os.makedirs(upload_dir, exist_ok=True)
            file_path = os.path.join(upload_dir, file.filename)
            file.save(file_path)
            
            new_doc = models.Document(
                project_id=uuid.UUID(proj_id_form),
                title=title,
                category=category,
                file_url=f"/{file_path}",
                uploaded_by=uuid.UUID(user_id)
            )
            db.add(new_doc)
            db.commit()
            flash('Document uploaded successfully.', 'success')
            return redirect(url_for('documents', project_id=proj_id_form))

    docs = []
    if project_id:
        docs = db.query(models.Document).filter(models.Document.project_id == uuid.UUID(project_id)).all()
        
    close_db(db)
    return render_template('documents.html', projects=projects, selected_project_id=project_id, documents=docs)

if __name__ == '__main__':
    app.run(debug=True, port=5050)
