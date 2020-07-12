import tempfile
import random
import re

from unittest import TestCase
from pippi import lists, dsp

class TestLists(TestCase):
    def test_scaled_list(self):
        source = [1,2,3]
        target = [3,4,5]
        result = dsp.scale(source, 1, 3, 3, 5)
        self.assertEqual(result, target)

    def test_log_scaled_list(self):
        source = [1,2,3,4,5,6]
        target = [
            6.0,
            7.476972645601738,
            8.615685818057926,
            9.542565334311575,
            10.324198625815951,
            11.0
        ]

        result = dsp.scale(source, 1, 6, 6, 11, log=True)
        self.assertEqual(result, target)

    def test_snapped_list(self):
        source = [1,2,3,4,5,6]
        pattern = [3,4,5]
        target = [3,3,3,4,5,5]
        result = dsp.snap(source, pattern=pattern)
        self.assertEqual(result, target)

        source = [1,2,3,4,5,6]
        target = [1.5,3,3,4.5,6,6]
        result = dsp.snap(source, 1.5)
        self.assertEqual(result, target)


