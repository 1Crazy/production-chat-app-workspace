export type ConversationType = 'direct' | 'group';

export interface ConversationEntity {
  id: string;
  type: ConversationType;
  title: string | null;
  createdBy: string;
  directKey: string | null;
  latestSequence: number;
  createdAt: Date;
  updatedAt: Date;
}
