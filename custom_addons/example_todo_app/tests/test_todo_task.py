# -*- coding: utf-8 -*-
from odoo.tests.common import TransactionCase
from odoo.exceptions import ValidationError
from datetime import date, timedelta


class TestTodoTask(TransactionCase):
    """Test Todo Task functionality"""
    
    def setUp(self):
        super().setUp()
        self.task_model = self.env['todo.task']
        self.user_demo = self.env.ref('base.user_demo')
        
        # Create test category
        self.category = self.env['todo.category'].create({
            'name': 'Test Category',
            'description': 'Category for testing'
        })
        
        # Create test tag
        self.tag = self.env['todo.tag'].create({
            'name': 'Test Tag'
        })
    
    def test_task_creation(self):
        """Test basic task creation"""
        task = self.task_model.create({
            'name': 'Test Task',
            'description': 'This is a test task',
            'assigned_to': self.user_demo.id,
            'category_id': self.category.id,
            'tag_ids': [(6, 0, [self.tag.id])]
        })
        
        self.assertEqual(task.name, 'Test Task')
        self.assertEqual(task.state, 'draft')
        self.assertEqual(task.assigned_to, self.user_demo)
        self.assertEqual(task.category_id, self.category)
        self.assertIn(self.tag, task.tag_ids)
    
    def test_task_state_transitions(self):
        """Test task state transitions"""
        task = self.task_model.create({
            'name': 'Test Task',
            'assigned_to': self.user_demo.id
        })
        
        # Test start action
        task.action_start()
        self.assertEqual(task.state, 'in_progress')
        
        # Test done action
        task.action_done()
        self.assertEqual(task.state, 'done')
        self.assertTrue(task.date_completed)
        
        # Test reset to draft
        task.action_reset_to_draft()
        self.assertEqual(task.state, 'draft')
        self.assertFalse(task.date_completed)
        
        # Test cancel action
        task.action_cancel()
        self.assertEqual(task.state, 'cancelled')
    
    def test_deadline_validation(self):
        """Test deadline validation for new tasks"""
        yesterday = date.today() - timedelta(days=1)
        
        with self.assertRaises(ValidationError):
            self.task_model.create({
                'name': 'Test Task',
                'date_deadline': yesterday,
                'state': 'draft'
            })
    
    def test_overdue_computation(self):
        """Test overdue field computation"""
        yesterday = date.today() - timedelta(days=1)
        tomorrow = date.today() + timedelta(days=1)
        
        # Create task with deadline yesterday
        task_overdue = self.task_model.create({
            'name': 'Overdue Task',
            'date_deadline': yesterday,
            'state': 'in_progress'  # Set to in_progress to bypass validation
        })
        
        # Create task with deadline tomorrow
        task_future = self.task_model.create({
            'name': 'Future Task',
            'date_deadline': tomorrow,
            'state': 'in_progress'
        })
        
        # Create completed task with deadline yesterday
        task_done = self.task_model.create({
            'name': 'Done Task',
            'date_deadline': yesterday,
            'state': 'done'
        })
        
        self.assertTrue(task_overdue.is_overdue)
        self.assertFalse(task_future.is_overdue)
        self.assertFalse(task_done.is_overdue)  # Done tasks are not overdue
    
    def test_progress_computation(self):
        """Test progress percentage computation"""
        task = self.task_model.create({
            'name': 'Test Task',
            'assigned_to': self.user_demo.id
        })
        
        # Draft state should be 0%
        self.assertEqual(task.progress_percentage, 0.0)
        
        # In progress should be 50%
        task.action_start()
        self.assertEqual(task.progress_percentage, 50.0)
        
        # Done should be 100%
        task.action_done()
        self.assertEqual(task.progress_percentage, 100.0)
    
    def test_assign_to_me(self):
        """Test assign to me functionality"""
        task = self.task_model.create({
            'name': 'Test Task',
            'assigned_to': self.user_demo.id
        })
        
        # Change context to different user
        task_as_admin = task.with_user(self.env.ref('base.user_admin'))
        task_as_admin.action_assign_to_me()
        
        self.assertEqual(task.assigned_to, self.env.ref('base.user_admin'))
    
    def test_category_task_count(self):
        """Test category task count computation"""
        initial_count = self.category.task_count
        
        # Create tasks in category
        self.task_model.create({
            'name': 'Task 1',
            'category_id': self.category.id
        })
        self.task_model.create({
            'name': 'Task 2',
            'category_id': self.category.id
        })
        
        self.assertEqual(self.category.task_count, initial_count + 2)
    
    def test_name_search(self):
        """Test custom name search functionality"""
        task = self.task_model.create({
            'name': 'Important Task',
            'description': 'This task contains special keywords'
        })
        
        # Search by name
        results = self.task_model.name_search('Important')
        task_ids = [r[0] for r in results]
        self.assertIn(task.id, task_ids)
        
        # Search by description
        results = self.task_model.name_search('special keywords')
        task_ids = [r[0] for r in results]
        self.assertIn(task.id, task_ids)