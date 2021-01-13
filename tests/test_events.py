from unittest import TestCase

from pippi.events import Event

class TestEvents(TestCase):
    def test_print(self):
        e = Event(foo='bar')         
        print(e.foo)
        print(e._params)

    def test_add_param(self):
        e = Event(foo='bar')         
        e.baz = 2
        self.assertEqual(e.baz, 2)
        e.baz = 1
        self.assertEqual(e.baz, 1)

