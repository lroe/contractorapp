# Organization Management Scripts

These scripts help manage organizations and user ownership in the Contractor DB system.

## Scripts

### 1. create_org.py
Creates a new organization.

**Usage:**
```bash
python3 scratch/create_org.py "Organization Name"
```

**Example:**
```bash
python3 scratch/create_org.py "ABC Construction Company"
```

**Output:**
```
Creating organization 'ABC Construction Company'...
✅ Successfully created organization:
   Name: ABC Construction Company
   ID: 12345678-1234-1234-1234-123456789abc

💡 To set an owner, run:
   python3 scratch/set_owner.py <email> 12345678-1234-1234-1234-123456789abc
```

### 2. set_owner.py
Sets a user as the owner of an organization.

**Usage:**
```bash
python3 scratch/set_owner.py <email> <organization_id>
```

**Example:**
```bash
python3 scratch/set_owner.py owner@example.com 12345678-1234-1234-1234-123456789abc
```

**Output:**
```
Setting user 'owner@example.com' as owner of organization '12345678-1234-1234-1234-123456789abc'...
✅ Successfully set user as owner:
   Email: owner@example.com
   Name: John Doe
   Organization: ABC Construction Company (12345678-1234-1234-1234-123456789abc)
   Role: owner
```

## Workflow

1. **Create Organization:**
   ```bash
   python3 scratch/create_org.py "My Company"
   ```

2. **Set Owner:**
   ```bash
   python3 scratch/set_owner.py user@example.com <org-id-from-step-1>
   ```

3. **Invite Team Members:**
   - Use the web portal team management page
   - Or use the mobile app team management (for owners)

## Notes

- The user must already exist in the system (registered via phone or Google)
- The organization ID is a UUID that gets generated when creating the organization
- Only one owner per organization is supported
- These scripts require database access and should be run from the project root directory