# -*- coding: utf-8 -*-
{
    'name': 'Example Todo App',
    'version': '18.0.1.0.0',
    'category': 'Productivity',
    'summary': 'Simple Todo application demonstrating Odoo 18 customization',
    'description': """
Example Todo Application
========================

This module demonstrates how to create custom applications in Odoo 18:

Features:
- Task management with priorities
- User assignment
- State workflow (draft, in progress, done, cancelled)
- Deadline tracking
- Categories and tags
- Custom reports
- Dashboard views

This is a complete example showing:
- Custom models and business logic
- Form, tree, search, and kanban views
- Security and access control
- Automated actions
- Custom reports
- Unit tests
    """,
    'author': 'Your Company',
    'website': 'https://yourcompany.com',
    'license': 'LGPL-3',
    'depends': ['base', 'mail'],
    'data': [
        'security/todo_security.xml',
        'security/ir.model.access.csv',
        'data/todo_data.xml',
        'views/todo_task_views.xml',
        'views/todo_category_views.xml',
        'views/todo_menus.xml',
        'reports/todo_reports.xml',
    ],
    'demo': [
        'data/todo_demo.xml',
    ],
    'assets': {
        'web.assets_backend': [
            'example_todo_app/static/src/css/todo_style.css',
        ],
    },
    'images': ['static/description/icon.png'],
    'installable': True,
    'auto_install': False,
    'application': True,
}