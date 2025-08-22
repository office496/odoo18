# -*- coding: utf-8 -*-
from odoo import models, fields, api


class TodoCategory(models.Model):
    """Todo Category Model - separate file for better organization"""
    
    _name = 'todo.category'
    _description = 'Todo Category'
    _order = 'name'
    
    name = fields.Char(string='Category Name', required=True)
    description = fields.Text(string='Description')
    color = fields.Integer(string='Color Index', default=0)
    active = fields.Boolean(string='Active', default=True)
    
    # Relations
    task_ids = fields.One2many('todo.task', 'category_id', string='Tasks')
    
    # Computed fields
    task_count = fields.Integer(
        string='Task Count',
        compute='_compute_task_count',
        store=True
    )
    
    @api.depends('task_ids')
    def _compute_task_count(self):
        """Compute number of tasks in category"""
        for category in self:
            category.task_count = len(category.task_ids)
    
    def action_view_tasks(self):
        """Action to view tasks in this category"""
        return {
            'name': f'Tasks in {self.name}',
            'type': 'ir.actions.act_window',
            'res_model': 'todo.task',
            'view_mode': 'tree,form,kanban',
            'domain': [('category_id', '=', self.id)],
            'context': {'default_category_id': self.id},
        }