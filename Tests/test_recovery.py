import importlib.util
from pathlib import Path
import unittest
spec = importlib.util.spec_from_file_location('layout', Path(__file__).resolve().parents[1] / 'Tools/check_layout.py')
layout = importlib.util.module_from_spec(spec)
spec.loader.exec_module(layout)

class RecoveryTests(unittest.TestCase):
    def test_partial_write_restores_first_key(self):
        values = [0, 2]
        def setter(index, value):
            if index == 1 and value is None:
                raise RuntimeError('disk failure')
            values[index] = value
        transaction = layout.Preferences(lambda: list(values), setter)
        with self.assertRaises(RuntimeError):
            transaction.write([24, None])
        self.assertEqual(values, [24, 2])
        transaction.restore()
        self.assertEqual(values, [0, 2])

    def test_external_change_is_not_overwritten(self):
        values = [0, 2]
        transaction = layout.Preferences(lambda: list(values), lambda i,v: values.__setitem__(i,v))
        transaction.write([24, None])
        values[0] = 12
        with self.assertRaisesRegex(RuntimeError, 'Concurrent'):
            transaction.restore()
        self.assertEqual(values, [12, None])

    def test_original_unset_values_preserved(self):
        values = [None, None]
        transaction = layout.Preferences(lambda: list(values), lambda i,v: values.__setitem__(i,v))
        transaction.write([0, 2]); transaction.restore()
        self.assertEqual(values, [None, None])

    def test_failure_after_write_restores(self):
        values = [0, 2]
        def setter(i, v):
            values[i] = v
            if v == 24: raise RuntimeError('command failed after writing')
        transaction = layout.Preferences(lambda: list(values), setter)
        with self.assertRaises(RuntimeError): transaction.write([24, None])
        transaction.restore()
        self.assertEqual(values, [0, 2])

if __name__ == '__main__': unittest.main()
