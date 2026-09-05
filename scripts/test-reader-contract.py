#!/usr/bin/env python3
"""Exercise the shipped playbook's reader handoff; this does not grade prose."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PLAYBOOK = ROOT / 'plugins/playbooks/authoring/write-doc'


class ReaderContractTest(unittest.TestCase):
    def test_reader_records_are_required_before_saving(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            env = dict(os.environ, XDG_STATE_HOME=str(base / 'state'))
            parsed = subprocess.run(['yq', '-o=json', '.', str(PLAYBOOK / 'playbook.yml')],
                                    check=True, text=True, capture_output=True)
            playbook = json.loads(parsed.stdout)
            config = base / 'resolved.json'
            config.write_text(json.dumps({'playbook': playbook}))

            def call(command, *arguments, expected=0):
                result = subprocess.run(['python3', str(PLAYBOOK / 'scripts/state.py'),
                                         command, '--config', str(config), '--run-id', 'reader-test',
                                         *arguments], env=env, text=True, capture_output=True)
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
                return result

            template = ROOT / 'plugins/skills/authoring/content-types/assets/templates/concept.md'
            context = base / 'reader-context.md'
            review = base / 'reader-review.md'
            body = base / 'document.md'
            call('init', '--repo', str(base))
            call('start', '--step', 'type')
            type_args = ['--step', 'type', '--provide', 'type=concept',
                         '--provide', f'template={template}']
            call('complete', *type_args, expected=2)
            call('complete', *type_args, '--provide', f'reader_context={context}', expected=2)
            context.write_text('Reader knows room reservations; distinguish a hold from confirmation.\n')
            call('complete', *type_args, '--provide', f'reader_context={context}')
            call('start', '--step', 'draft')
            body.write_text('# A reservation hold\nAn illustrative document for the contract test.\n')
            draft_args = ['--step', 'draft', '--provide', f'body={body}',
                          '--provide', 'roles_applied=none']
            call('complete', *draft_args, expected=2)
            call('complete', *draft_args, '--provide', f'reader_review={review}', expected=2)
            review.write_text('Contract fixture only; prose quality is not being evaluated here.\n')
            call('complete', *draft_args, '--provide', f'reader_review={review}')
            call('start', '--step', 'visual')
            self.assertFalse(playbook['requirements']['figures'])
            call('complete', '--step', 'visual', '--provide', 'figures_applied=0')
            call('start', '--step', 'save')
            call('complete', '--step', 'save', '--provide', f'path={body}')
            status = json.loads(call('status').stdout)
            self.assertEqual(status['status'], 'completed')
            self.assertEqual(status['artifacts']['reader_context'], str(context))
            self.assertEqual(status['artifacts']['reader_review'], str(review))


if __name__ == '__main__':
    unittest.main()
