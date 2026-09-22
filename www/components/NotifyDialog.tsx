'use client';

import Image from 'next/image';
import { useEffect, useRef, useState, type ReactNode } from 'react';
import { InterestForm } from '@/components/InterestForm';

type NotifyButtonProps = {
  children?: ReactNode;
  className?: string;
  onOpen?: () => void;
};

export function NotifyButton({ children = 'Notify me', className = '', onOpen }: NotifyButtonProps) {
  return (
    <button type="button" data-notify-trigger className={`notify-trigger fill-link ${className}`.trim()} onClick={onOpen}>
      <span>{children}</span>
    </button>
  );
}

export function NotifyDialog() {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const openerRef = useRef<HTMLElement | null>(null);
  const [formInstance, setFormInstance] = useState(0);

  useEffect(() => {
    if (formInstance > 0) document.dispatchEvent(new Event('eurotrex:notify-form-ready'));
  }, [formInstance]);

  useEffect(() => {
    const open = () => {
      const dialog = dialogRef.current;
      if (!dialog || dialog.open) return;
      openerRef.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
      setFormInstance((instance) => instance + 1);
      document.documentElement.classList.add('modal-open');
      dialog.showModal();
    };

    const handleTrigger = (event: MouseEvent) => {
      const target = event.target;
      if (target instanceof Element && target.closest('[data-notify-trigger]')) open();
    };

    document.addEventListener('click', handleTrigger);
    return () => {
      document.removeEventListener('click', handleTrigger);
      document.documentElement.classList.remove('modal-open');
    };
  }, []);

  function closeDialog() {
    dialogRef.current?.close();
  }

  function handleClose() {
    document.documentElement.classList.remove('modal-open');
    openerRef.current?.focus();
  }

  return (
    <dialog
      ref={dialogRef}
      className="notify-dialog"
      aria-labelledby="notify-dialog-title"
      onClose={handleClose}
      onClick={(event) => { if (event.target === event.currentTarget) closeDialog(); }}
    >
      <div className="notify-dialog-panel">
        <button className="notify-dialog-close" type="button" onClick={closeDialog} aria-label="Close notification form">×</button>
        <div className="notify-dialog-heading">
          <Image className="notify-dialog-icon" src="/eurotrex-app-icon.png" alt="" width={1024} height={1024} sizes="64px" />
          <div>
            <p className="eyebrow">App updates</p>
            <h2 id="notify-dialog-title">Know when EuroTrex is ready.</h2>
          </div>
        </div>
        <p className="notify-dialog-intro">Tell us where to reach you and we’ll share testing invitations and official store links when they are available.</p>
        <InterestForm key={formInstance} kind="beta" compact />
      </div>
    </dialog>
  );
}
