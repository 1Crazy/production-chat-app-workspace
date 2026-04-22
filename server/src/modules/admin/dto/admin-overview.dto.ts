export interface AdminOverviewDto {
  users: {
    total: number;
    disabled: number;
  };
  sessions: {
    active: number;
  };
  conversations: {
    total: number;
    direct: number;
    group: number;
  };
  reports: {
    total: number;
    pendingReview: number;
    reviewed: number;
    resolved: number;
    rejected: number;
  };
}
