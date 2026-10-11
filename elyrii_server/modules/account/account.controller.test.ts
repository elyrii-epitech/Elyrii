import {describe, expect, test} from 'bun:test';
import {canModerate, aiReportSchema} from './account.controller';
describe('AI reporting authorization and data minimization', () => {
  test('empty or unknown staff configuration grants nobody moderation access', () => {
    expect(canModerate('visitor', '')).toBe(false);
    expect(canModerate('visitor', 'staff-a,staff-b')).toBe(false);
    expect(canModerate('staff-a', ' staff-a,staff-b ')).toBe(true);
    expect(canModerate('staff', 'staff-a')).toBe(false);
  });
  test('the report is bounded and unrelated client fields cannot select an owner or staff status', () => {
    const input = {messageId: crypto.randomUUID(), conversationId: 'local-conversation', reason: 'DANGEROUS', content: 'Selected response only', userId: 'another-user', status: 'ACTIONED', history: ['private']};
    const parsed = aiReportSchema.parse(input);
    expect(parsed).not.toHaveProperty('userId'); expect(parsed).not.toHaveProperty('status'); expect(parsed).not.toHaveProperty('history');
    expect(aiReportSchema.safeParse({...input, content: 'x'.repeat(16001)}).success).toBe(false);
    expect(aiReportSchema.safeParse({...input, messageId: 'arbitrary'}).success).toBe(false);
  });
});
