import Image from 'next/image';
import type { ReactNode } from 'react';
import { InterestForm } from '@/components/InterestForm';

type NotifyButtonProps = {
  children?: ReactNode;
  className?: string;
};

export function NotifyButton({ children = 'Notify me', className = '' }: NotifyButtonProps) {
  return (
    <button
      type="button"
      aria-controls="notify-dialog"
      aria-haspopup="dialog"
      data-notify-trigger
      className={`notify-trigger fill-link ${className}`.trim()}
    >
      <span>{children}</span>
    </button>
  );
}

export function NotifyDialog() {
  return (
    <dialog
      id="notify-dialog"
      className="notify-dialog"
      aria-labelledby="notify-dialog-title"
      data-notify-dialog
    >
      <div className="notify-dialog-panel">
        <button className="notify-dialog-close" type="button" data-notify-close aria-label="Close notification form">×</button>
        <div className="notify-dialog-heading">
          <Image className="notify-dialog-icon" src="/eurotrex-app-icon.png" alt="" width={1024} height={1024} sizes="64px" />
          <div>
            <p className="eyebrow">App updates</p>
            <h2 id="notify-dialog-title">Know when EuroTrex is ready.</h2>
          </div>
        </div>
        <p className="notify-dialog-intro">Tell us where to reach you and we’ll share testing invitations and official store links when they are available.</p>
        <InterestForm kind="beta" compact />
      </div>
    </dialog>
  );
}
