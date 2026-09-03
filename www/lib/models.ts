export type SubmissionStatus =
  | 'draft'
  | 'pending'
  | 'pending_update'
  | 'changes_requested'
  | 'approved'
  | 'rejected'
  | 'removed';

export type AccommodationSubmission = {
  id: string;
  ownerId: string;
  ownerEmail: string;
  trailId: string;
  trailName: string;
  stageId: string;
  stageName: string;
  stageSequence?: number;
  name: string;
  type: string;
  village: string;
  address: string;
  description: string;
  phone: string;
  email: string;
  website: string;
  whatsapp?: string;
  googleMapsUrl?: string;
  priceMinEur?: number;
  priceMaxEur?: number;
  distanceFromTrailKm?: number;
  capacityPeople?: number;
  monthsOpen?: string;
  latitude?: number;
  longitude?: number;
  status: SubmissionStatus;
  policyAgreement: boolean;
  reviewNote?: string;
  publishedLodgingId?: string;
  createdAt?: unknown;
  updatedAt?: unknown;
};

export type TrailOption = { id: string; name: string };
export type StageOption = { id: string; name: string; sequence: number };

export type PublishedLodging = {
  id: string;
  trailId: string;
  name?: string;
  type?: string;
  village?: string;
  stageName?: string;
  stageId?: string;
  ownerId?: string;
  sourceSubmissionId?: string;
};

export type AuditEntry = {
  id: string;
  submissionId?: string;
  lodgingId?: string;
  trailId?: string;
  ownerId?: string;
  accommodationName?: string;
  action?: string;
  note?: string;
  actorEmail?: string;
  createdAt?: { toDate?: () => Date };
};

export const statusLabels: Record<SubmissionStatus, string> = {
  draft: 'Draft',
  pending: 'Awaiting review',
  pending_update: 'Update awaiting review',
  changes_requested: 'Changes requested',
  approved: 'Live in EuroTrex',
  rejected: 'Not approved',
  removed: 'Removed',
};
