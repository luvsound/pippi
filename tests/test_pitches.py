from unittest import TestCase
from pippi import tune

class TestPitches(TestCase):
    def test_ntm(self):
        notes = [57, 58, 59, 60, 61, 62, 63, 64, 65, 66]
        self.assertEqual(notes, [tune.ntm(n) for n in ['a3', 'a#3', 'b3', 'c4', 'c#4', 'd4', 'd#4', 'e4', 'f4', 'f#4']])
