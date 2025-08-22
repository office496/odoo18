# -*- coding: utf-8 -*-
from odoo import models, fields, api
from odoo.exceptions import ValidationError
from datetime import datetime, timedelta


class TodoTask(models.Model):
    """Todo Task Model - demonstrates Odoo 18 model features"""
    
    _name = 'todo.task'
    _description = 'Todo Task'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _order = 'priority desc, date_deadline, sequence, id'
    _rec_name = 'name'
    
    # Basic fields
    name = fields.Char(
        string='Task Name', 
        required=True, 
        tracking=True,
        help="Name of the task"
    )
    description = fields.Html(
        string='Description',
        help="Detailed description of the task"
    )
    sequence = fields.Integer(
        string='Sequence',
        default=10,
        help="Used to order tasks"
    )
    
    # Dates
    date_created = fields.Datetime(
        string='Created Date',
        default=fields.Datetime.now,
        readonly=True
    )
    date_deadline = fields.Date(
        string='Deadline',
        tracking=True,
        help="When the task should be completed"
    )
    date_completed = fields.Datetime(
        string='Completed Date',
        readonly=True
    )
    
    # Status and priority
    state = fields.Selection([
        ('draft', 'Draft'),
        ('in_progress', 'In Progress'),
        ('done', 'Done'),
        ('cancelled', 'Cancelled')
    ], string='State', default='draft', tracking=True)
    
    priority = fields.Selection([
        ('0', 'Low'),
        ('1', 'Normal'),
        ('2', 'High'),
        ('3', 'Urgent')
    ], string='Priority', default='1', tracking=True)
    
    # Relations
    assigned_to = fields.Many2one(
        'res.users',
        string='Assigned To',
        tracking=True,
        help="User responsible for this task"
    )
    category_id = fields.Many2one(
        'todo.category',
        string='Category',
        help="Task category"
    )
    tag_ids = fields.Many2many(
        'todo.tag',
        string='Tags',
        help="Task tags for organization"
    )
    
    # Computed fields
    is_overdue = fields.Boolean(
        string='Overdue',
        compute='_compute_is_overdue',
        store=True,
        help="True if task is past deadline"
    )
    days_to_deadline = fields.Integer(
        string='Days to Deadline',
        compute='_compute_days_to_deadline',
        help="Number of days until deadline"
    )
    progress_percentage = fields.Float(
        string='Progress %',
        compute='_compute_progress_percentage',
        store=True,
        help="Task completion percentage"
    )
    
    # Additional fields
    active = fields.Boolean(string='Active', default=True)
    color = fields.Integer(string='Color Index', default=0)
    notes = fields.Text(string='Internal Notes')
    
    # Constraints
    @api.constrains('date_deadline')
    def _check_deadline(self):
        """Ensure deadline is not in the past for new tasks"""
        for task in self:
            if (task.date_deadline and 
                task.date_deadline < fields.Date.today() and 
                task.state == 'draft'):
                raise ValidationError(
                    "Deadline cannot be in the past for new tasks"
                )
    
    @api.constrains('assigned_to')
    def _check_assigned_user(self):
        """Ensure assigned user is active"""
        for task in self:
            if task.assigned_to and not task.assigned_to.active:
                raise ValidationError(
                    "Cannot assign task to inactive user"
                )
    
    # Computed field methods
    @api.depends('date_deadline', 'state')
    def _compute_is_overdue(self):
        """Compute if task is overdue"""
        today = fields.Date.today()
        for task in self:
            task.is_overdue = (
                task.date_deadline and 
                task.date_deadline < today and
                task.state not in ['done', 'cancelled']
            )
    
    @api.depends('date_deadline')
    def _compute_days_to_deadline(self):
        """Compute days until deadline"""
        today = fields.Date.today()
        for task in self:
            if task.date_deadline:
                delta = task.date_deadline - today
                task.days_to_deadline = delta.days
            else:
                task.days_to_deadline = 0
    
    @api.depends('state')
    def _compute_progress_percentage(self):
        """Compute task progress percentage"""
        progress_map = {
            'draft': 0.0,
            'in_progress': 50.0,
            'done': 100.0,
            'cancelled': 0.0
        }
        for task in self:
            task.progress_percentage = progress_map.get(task.state, 0.0)
    
    # CRUD overrides
    @api.model_create_multi
    def create(self, vals_list):
        """Override create to set defaults and send notifications"""
        for vals in vals_list:
            # Auto-assign to current user if not specified
            if not vals.get('assigned_to'):
                vals['assigned_to'] = self.env.user.id
        
        tasks = super().create(vals_list)
        
        # Send notification for assigned tasks
        for task in tasks:
            if task.assigned_to != self.env.user:
                task.message_post(
                    body=f"Task '{task.name}' has been assigned to you.",
                    message_type='notification',
                    partner_ids=[task.assigned_to.partner_id.id]
                )
        
        return tasks
    
    def write(self, vals):
        """Override write to handle state changes"""
        # Record completion date when task is done
        if vals.get('state') == 'done':
            vals['date_completed'] = fields.Datetime.now()
        elif vals.get('state') in ['draft', 'in_progress', 'cancelled']:
            vals['date_completed'] = False
        
        # Send notification on assignment change
        if 'assigned_to' in vals:
            for task in self:
                old_user = task.assigned_to
                new_user = self.env['res.users'].browse(vals['assigned_to']) if vals['assigned_to'] else False
                
                if old_user != new_user and new_user:
                    task.message_post(
                        body=f"Task '{task.name}' has been reassigned to you.",
                        message_type='notification',
                        partner_ids=[new_user.partner_id.id]
                    )
        
        return super().write(vals)
    
    # Action methods
    def action_start(self):
        """Start the task"""
        self.write({'state': 'in_progress'})
        return True
    
    def action_done(self):
        """Mark task as done"""
        self.write({'state': 'done'})
        return True
    
    def action_cancel(self):
        """Cancel the task"""
        self.write({'state': 'cancelled'})
        return True
    
    def action_reset_to_draft(self):
        """Reset task to draft"""
        self.write({'state': 'draft'})
        return True
    
    def action_assign_to_me(self):
        """Assign task to current user"""
        self.write({'assigned_to': self.env.user.id})
        return True
    
    # Automated methods
    @api.model
    def _cron_check_deadlines(self):
        """Cron job to check for approaching deadlines"""
        tomorrow = fields.Date.today() + timedelta(days=1)
        
        # Find tasks due tomorrow
        tasks_due_tomorrow = self.search([
            ('date_deadline', '=', tomorrow),
            ('state', 'in', ['draft', 'in_progress']),
            ('assigned_to', '!=', False)
        ])
        
        for task in tasks_due_tomorrow:
            task.message_post(
                body=f"Reminder: Task '{task.name}' is due tomorrow!",
                message_type='notification',
                partner_ids=[task.assigned_to.partner_id.id]
            )
    
    # Search methods
    @api.model
    def _name_search(self, name='', args=None, operator='ilike', limit=100, name_get_uid=None):
        """Custom name search to include description"""
        args = args or []
        domain = []
        
        if name:
            domain = ['|', ('name', operator, name), ('description', operator, name)]
        
        return self._search(domain + args, limit=limit, access_rights_uid=name_get_uid)


class TodoCategory(models.Model):
    """Todo Category Model"""
    
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


class TodoTag(models.Model):
    """Todo Tag Model"""
    
    _name = 'todo.tag'
    _description = 'Todo Tag'
    _order = 'name'
    
    name = fields.Char(string='Tag Name', required=True)
    color = fields.Integer(string='Color Index', default=0)
    active = fields.Boolean(string='Active', default=True)
    
    _sql_constraints = [
        ('name_unique', 'UNIQUE(name)', 'Tag name must be unique!')
    ]