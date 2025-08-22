# Odoo 18 Customization Guide

This guide covers how to customize Odoo 18 through module development, configuration, and theming.

## Table of Contents

1. [Module Development](#module-development)
2. [Model Customization](#model-customization)
3. [View Customization](#view-customization)
4. [Business Logic](#business-logic)
5. [Reports](#reports)
6. [Security](#security)
7. [API Development](#api-development)
8. [Theming](#theming)
9. [Best Practices](#best-practices)

## Module Development

### Creating a New Module

Use the module helper script to create a new module:

```bash
./deployment/scripts/module_helper.sh create my_custom_module
```

Or use the Odoo scaffold command directly:

```bash
./odoo-bin scaffold my_custom_module custom_addons/
```

### Module Structure

A typical Odoo module structure:

```
my_custom_module/
├── __init__.py              # Python package initialization
├── __manifest__.py          # Module manifest (metadata)
├── models/                  # Python models (database tables)
│   ├── __init__.py
│   └── my_model.py
├── views/                   # XML view definitions
│   ├── my_model_views.xml
│   └── menus.xml
├── security/                # Access control
│   └── ir.model.access.csv
├── data/                    # Data files (CSV, XML)
│   └── demo_data.xml
├── static/                  # Static files (CSS, JS, images)
│   ├── description/
│   │   └── icon.png
│   └── src/
│       ├── css/
│       ├── js/
│       └── xml/
├── tests/                   # Unit tests
│   ├── __init__.py
│   └── test_my_model.py
├── wizard/                  # Wizard dialogs
│   ├── __init__.py
│   └── my_wizard.py
└── report/                  # Report templates
    └── my_report.xml
```

### Module Manifest (__manifest__.py)

```python
{
    'name': 'My Custom Module',
    'version': '18.0.1.0.0',
    'category': 'Custom',
    'summary': 'Brief description of the module',
    'description': """
        Longer description of what the module does.
        Can be multi-line.
    """,
    'author': 'Your Name',
    'website': 'https://yourwebsite.com',
    'license': 'LGPL-3',
    'depends': ['base', 'sale', 'account'],  # Dependencies
    'data': [
        'security/ir.model.access.csv',
        'views/my_model_views.xml',
        'views/menus.xml',
        'data/demo_data.xml',
    ],
    'demo': [
        'data/demo_data.xml',
    ],
    'assets': {
        'web.assets_backend': [
            'my_custom_module/static/src/css/my_style.css',
            'my_custom_module/static/src/js/my_script.js',
        ],
    },
    'installable': True,
    'auto_install': False,
    'application': False,
}
```

## Model Customization

### Creating New Models

Create a new model in `models/my_model.py`:

```python
from odoo import models, fields, api
from odoo.exceptions import ValidationError

class MyCustomModel(models.Model):
    _name = 'my.custom.model'
    _description = 'My Custom Model'
    _order = 'name'
    
    name = fields.Char(string='Name', required=True)
    description = fields.Text(string='Description')
    date_created = fields.Datetime(string='Created Date', default=fields.Datetime.now)
    active = fields.Boolean(string='Active', default=True)
    priority = fields.Selection([
        ('low', 'Low'),
        ('medium', 'Medium'),
        ('high', 'High')
    ], string='Priority', default='medium')
    
    # Computed field
    display_name_upper = fields.Char(string='Upper Name', compute='_compute_display_name_upper')
    
    # Relational fields
    partner_id = fields.Many2one('res.partner', string='Partner')
    line_ids = fields.One2many('my.custom.line', 'parent_id', string='Lines')
    tag_ids = fields.Many2many('my.custom.tag', string='Tags')
    
    @api.depends('name')
    def _compute_display_name_upper(self):
        for record in self:
            record.display_name_upper = record.name.upper() if record.name else ''
    
    @api.constrains('name')
    def _check_name_length(self):
        for record in self:
            if len(record.name) < 3:
                raise ValidationError("Name must be at least 3 characters long")
    
    def action_confirm(self):
        """Custom action method"""
        self.write({'state': 'confirmed'})
        return True
```

### Extending Existing Models

Extend existing models by inheriting:

```python
from odoo import models, fields, api

class ResPartnerExtended(models.Model):
    _inherit = 'res.partner'
    
    # Add new fields
    custom_field = fields.Char(string='Custom Field')
    special_discount = fields.Float(string='Special Discount %')
    
    # Override existing methods
    @api.model
    def create(self, vals):
        """Override create method"""
        # Custom logic before create
        result = super(ResPartnerExtended, self).create(vals)
        # Custom logic after create
        return result
```

## View Customization

### Form Views

Create form views in `views/my_model_views.xml`:

```xml
<odoo>
    <data>
        <record id="view_my_custom_model_form" model="ir.ui.view">
            <field name="name">my.custom.model.form</field>
            <field name="model">my.custom.model</field>
            <field name="arch" type="xml">
                <form string="My Custom Model">
                    <header>
                        <button name="action_confirm" string="Confirm" type="object" class="oe_highlight"/>
                    </header>
                    <sheet>
                        <group>
                            <group>
                                <field name="name"/>
                                <field name="priority"/>
                                <field name="partner_id"/>
                            </group>
                            <group>
                                <field name="date_created"/>
                                <field name="active"/>
                            </group>
                        </group>
                        <notebook>
                            <page string="Description">
                                <field name="description"/>
                            </page>
                            <page string="Lines">
                                <field name="line_ids">
                                    <tree editable="bottom">
                                        <field name="name"/>
                                        <field name="quantity"/>
                                        <field name="price"/>
                                    </tree>
                                </field>
                            </page>
                        </notebook>
                    </sheet>
                </form>
            </field>
        </record>
    </data>
</odoo>
```

### Tree Views

```xml
<record id="view_my_custom_model_tree" model="ir.ui.view">
    <field name="name">my.custom.model.tree</field>
    <field name="model">my.custom.model</field>
    <field name="arch" type="xml">
        <tree string="My Custom Models">
            <field name="name"/>
            <field name="priority"/>
            <field name="partner_id"/>
            <field name="date_created"/>
            <field name="active"/>
        </tree>
    </field>
</record>
```

### Search Views

```xml
<record id="view_my_custom_model_search" model="ir.ui.view">
    <field name="name">my.custom.model.search</field>
    <field name="model">my.custom.model</field>
    <field name="arch" type="xml">
        <search string="Search My Custom Models">
            <field name="name"/>
            <field name="partner_id"/>
            <filter name="active" string="Active" domain="[('active', '=', True)]"/>
            <filter name="high_priority" string="High Priority" domain="[('priority', '=', 'high')]"/>
            <group expand="0" string="Group By">
                <filter name="group_partner" string="Partner" domain="[]" context="{'group_by': 'partner_id'}"/>
                <filter name="group_priority" string="Priority" domain="[]" context="{'group_by': 'priority'}"/>
            </group>
        </search>
    </field>
</record>
```

### Actions and Menus

```xml
<record id="action_my_custom_model" model="ir.actions.act_window">
    <field name="name">My Custom Models</field>
    <field name="res_model">my.custom.model</field>
    <field name="view_mode">tree,form</field>
    <field name="help" type="html">
        <p class="o_view_nocontent_smiling_face">
            Create your first custom record!
        </p>
    </field>
</record>

<menuitem id="menu_my_custom_module_root" name="My Custom Module" sequence="10"/>
<menuitem id="menu_my_custom_model" name="My Models" 
          parent="menu_my_custom_module_root" 
          action="action_my_custom_model" 
          sequence="10"/>
```

## Business Logic

### Workflow States

Implement state workflows:

```python
class MyCustomModel(models.Model):
    _name = 'my.custom.model'
    
    state = fields.Selection([
        ('draft', 'Draft'),
        ('confirmed', 'Confirmed'),
        ('done', 'Done'),
        ('cancelled', 'Cancelled')
    ], string='State', default='draft')
    
    def action_confirm(self):
        self.write({'state': 'confirmed'})
    
    def action_done(self):
        self.write({'state': 'done'})
    
    def action_cancel(self):
        self.write({'state': 'cancelled'})
    
    def action_reset_to_draft(self):
        self.write({'state': 'draft'})
```

### Automated Actions

Create automated actions for business rules:

```xml
<record id="automated_action_my_model" model="base.automation">
    <field name="name">My Model Automation</field>
    <field name="model_id" ref="model_my_custom_model"/>
    <field name="trigger">on_write</field>
    <field name="filter_pre_domain">[['state', '=', 'draft']]</field>
    <field name="filter_domain">[['state', '=', 'confirmed']]</field>
    <field name="code">
        # Python code to execute
        for record in records:
            record.date_confirmed = fields.Datetime.now()
    </field>
</record>
```

## Reports

### QWeb Reports

Create custom reports using QWeb:

```xml
<record id="report_my_custom_model" model="ir.actions.report">
    <field name="name">My Custom Report</field>
    <field name="model">my.custom.model</field>
    <field name="report_type">qweb-pdf</field>
    <field name="report_name">my_custom_module.report_my_custom_model_document</field>
    <field name="report_file">my_custom_module.report_my_custom_model_document</field>
    <field name="binding_model_id" ref="model_my_custom_model"/>
    <field name="binding_type">report</field>
</record>

<template id="report_my_custom_model_document">
    <t t-call="web.html_container">
        <t t-foreach="docs" t-as="doc">
            <t t-call="web.external_layout">
                <div class="page">
                    <h2><span t-field="doc.name"/></h2>
                    <div class="row">
                        <div class="col-6">
                            <strong>Partner:</strong> <span t-field="doc.partner_id.name"/>
                        </div>
                        <div class="col-6">
                            <strong>Date:</strong> <span t-field="doc.date_created"/>
                        </div>
                    </div>
                    <table class="table table-striped">
                        <thead>
                            <tr>
                                <th>Line</th>
                                <th>Quantity</th>
                                <th>Price</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr t-foreach="doc.line_ids" t-as="line">
                                <td><span t-field="line.name"/></td>
                                <td><span t-field="line.quantity"/></td>
                                <td><span t-field="line.price"/></td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </t>
        </t>
    </t>
</template>
```

## Security

### Access Control Lists

Define access rights in `security/ir.model.access.csv`:

```csv
id,name,model_id:id,group_id:id,perm_read,perm_write,perm_create,perm_unlink
access_my_custom_model_user,my.custom.model.user,model_my_custom_model,base.group_user,1,1,1,0
access_my_custom_model_manager,my.custom.model.manager,model_my_custom_model,base.group_system,1,1,1,1
```

### Record Rules

Define record-level security:

```xml
<record id="rule_my_custom_model_user" model="ir.rule">
    <field name="name">My Custom Model: User Access</field>
    <field name="model_id" ref="model_my_custom_model"/>
    <field name="domain_force">[('partner_id.user_id', '=', user.id)]</field>
    <field name="groups" eval="[(4, ref('base.group_user'))]"/>
</record>
```

## API Development

### REST API Controller

Create REST API endpoints:

```python
from odoo import http
from odoo.http import request
import json

class MyCustomAPIController(http.Controller):
    
    @http.route('/api/my_custom_model', type='http', auth='user', methods=['GET'], csrf=False)
    def get_my_models(self, **kwargs):
        """Get all my custom models"""
        records = request.env['my.custom.model'].search([])
        data = []
        for record in records:
            data.append({
                'id': record.id,
                'name': record.name,
                'priority': record.priority,
                'partner': record.partner_id.name if record.partner_id else None,
            })
        return json.dumps({'data': data})
    
    @http.route('/api/my_custom_model', type='json', auth='user', methods=['POST'], csrf=False)
    def create_my_model(self, **kwargs):
        """Create a new custom model"""
        data = request.jsonrequest
        record = request.env['my.custom.model'].create({
            'name': data.get('name'),
            'description': data.get('description'),
            'priority': data.get('priority', 'medium'),
        })
        return {'id': record.id, 'name': record.name}
```

## Theming

### Website Theme

Create a website theme by inheriting from existing templates:

```xml
<template id="custom_header" inherit_id="website.layout" name="Custom Header">
    <xpath expr="//header" position="replace">
        <header class="custom-header">
            <!-- Custom header content -->
        </header>
    </xpath>
</template>
```

### CSS Customization

Add custom CSS in `static/src/css/custom.css`:

```css
.custom-header {
    background-color: #333;
    color: white;
    padding: 20px;
}

.o_form_view .custom-field {
    background-color: #f0f0f0;
    border: 1px solid #ddd;
    border-radius: 4px;
    padding: 8px;
}
```

### JavaScript Customization

Add custom JavaScript in `static/src/js/custom.js`:

```javascript
odoo.define('my_custom_module.custom_widget', function (require) {
    'use strict';
    
    var AbstractField = require('web.AbstractField');
    var fieldRegistry = require('web.field_registry');
    
    var CustomWidget = AbstractField.extend({
        template: 'CustomWidgetTemplate',
        
        _renderReadonly: function () {
            this.$el.text(this.value || '');
        },
        
        _renderEdit: function () {
            this.$el.html('<input type="text" class="o_input" />');
            this.$('input').val(this.value || '');
        },
    });
    
    fieldRegistry.add('custom_widget', CustomWidget);
    
    return CustomWidget;
});
```

## Best Practices

### Code Quality

1. **Follow PEP 8** for Python code formatting
2. **Use meaningful names** for variables, methods, and classes
3. **Add docstrings** to all methods and classes
4. **Handle exceptions** properly
5. **Write unit tests** for business logic

### Performance

1. **Use appropriate field types** (e.g., Selection instead of Char for limited options)
2. **Add database indexes** for frequently searched fields
3. **Avoid N+1 queries** by using proper prefetching
4. **Use computed fields** sparingly and efficiently
5. **Implement pagination** for large datasets

### Security

1. **Always validate user input**
2. **Use proper access control lists**
3. **Implement record rules** for multi-tenancy
4. **Sanitize data** before displaying in templates
5. **Use HTTPS** in production

### Maintainability

1. **Follow Odoo conventions** for module structure
2. **Keep business logic in models**, not in controllers
3. **Use inheritance** appropriately
4. **Document configuration** and dependencies
5. **Version your modules** properly

## Example: Complete Custom Module

Here's a complete example of a simple task management module:

### models/task.py
```python
from odoo import models, fields, api
from odoo.exceptions import ValidationError

class Task(models.Model):
    _name = 'custom.task'
    _description = 'Custom Task'
    _order = 'priority desc, date_deadline'
    
    name = fields.Char(string='Task Name', required=True)
    description = fields.Text(string='Description')
    assigned_to = fields.Many2one('res.users', string='Assigned To')
    date_deadline = fields.Date(string='Deadline')
    priority = fields.Selection([
        ('0', 'Low'),
        ('1', 'Normal'),
        ('2', 'High'),
        ('3', 'Urgent')
    ], string='Priority', default='1')
    state = fields.Selection([
        ('draft', 'Draft'),
        ('in_progress', 'In Progress'),
        ('done', 'Done'),
        ('cancelled', 'Cancelled')
    ], string='State', default='draft')
    
    @api.constrains('date_deadline')
    def _check_deadline(self):
        for task in self:
            if task.date_deadline and task.date_deadline < fields.Date.today():
                raise ValidationError("Deadline cannot be in the past")
    
    def action_start(self):
        self.write({'state': 'in_progress'})
    
    def action_done(self):
        self.write({'state': 'done'})
```

This complete customization guide provides the foundation for developing custom Odoo 18 modules and extending existing functionality.