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
            persona = ROOT / 'plugins/skills/authoring/content-types/assets/personas/backend-1.md'
            context = base / 'reader-context.md'
            goals = base / 'goal-questions.md'
            questions = base / 'open-questions.md'
            review = base / 'reader-review.md'
            path_table = base / 'reading-path.md'
            body = base / 'document.md'
            judgement = base / 'judgement.md'
            call('init', '--repo', str(base))
            call('start', '--step', 'reader')
            reader_args = ['--step', 'reader', '--provide', 'type=concept',
                           '--provide', f'template={template}',
                           '--provide', f'persona={persona}']
            call('complete', *reader_args, expected=2)
            call('complete', *reader_args, '--provide', f'reader_context={context}', expected=2)
            context.write_text('Reader knows room reservations; distinguish a hold from confirmation.\n')
            # 到達点の問いが無いまま先へ進めない。判定の基準がここで決まるため。
            questions.write_text('count: 0\n')
            call('complete', *reader_args, '--provide', f'reader_context={context}',
                 '--provide', f'open_questions={questions}', expected=2)
            goals.write_text('- question: What ends a hold?\n')
            call('complete', *reader_args, '--provide', f'reader_context={context}',
                 '--provide', f'open_questions={questions}',
                 '--provide', f'goal_questions={goals}')
            # settle は when 付きなので、問いが無ければ skip で飛ばす。条件の無い工程は飛ばせない。
            call('skip', '--step', 'draft', expected=2)
            call('skip', '--step', 'settle', '--reason', 'open_questions.count == 0')
            call('start', '--step', 'draft')
            body.write_text('# A reservation hold\nAn illustrative document for the contract test.\n')
            draft_args = ['--step', 'draft', '--provide', f'body={body}',
                          '--provide', 'roles_applied=none']
            call('complete', *draft_args, expected=2)
            call('complete', *draft_args, '--provide', f'reader_review={review}', expected=2)
            review.write_text('Contract fixture only; prose quality is not being evaluated here.\n')
            call('complete', *draft_args, '--provide', f'reader_review={review}', expected=2)
            call('complete', *draft_args, '--provide', f'reader_review={review}',
                 '--provide', f'reading_path={path_table}', expected=2)
            path_table.write_text('| concept | foothold | introduced | first used |\n')
            call('complete', *draft_args, '--provide', f'reader_review={review}',
                 '--provide', f'reading_path={path_table}')
            call('start', '--step', 'visual')
            self.assertFalse(playbook['requirements']['figures'])
            call('complete', '--step', 'visual', '--provide', 'figures_applied=0')
            # 判定を通す前に保存できない。判定は保存より前に置いてある。
            call('start', '--step', 'save', expected=2)
            call('start', '--step', 'judge')
            call('complete', '--step', 'judge', expected=2)
            call('fail', '--step', 'judge', '--reason', 'fixture: reader got stuck on an undefined term')
            call('retry')
            call('start', '--step', 'judge')
            judgement.write_text('State contract fixture only; no semantic quality claim.\n')
            call('complete', '--step', 'judge', '--provide', f'judgement={judgement}')
            call('start', '--step', 'save')
            call('complete', '--step', 'save', '--provide', f'path={body}')
            status = json.loads(call('status').stdout)
            self.assertEqual(status['status'], 'completed')
            self.assertEqual(status['artifacts']['reader_context'], str(context))
            self.assertEqual(status['artifacts']['goal_questions'], str(goals))
            self.assertEqual(status['artifacts']['persona'], str(persona))
            self.assertEqual(status['artifacts']['judgement'], str(judgement))
            self.assertEqual(status['artifacts']['reading_path'], str(path_table))
            self.assertNotIn('decisions', status['artifacts'])
            settle = next(step for step in status['steps'] if step['id'] == 'settle')
            self.assertEqual(settle['status'], 'skipped')


if __name__ == '__main__':
    unittest.main()
