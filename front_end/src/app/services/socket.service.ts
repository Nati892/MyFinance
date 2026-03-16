import { Injectable, OnDestroy } from '@angular/core';
import { Subject } from 'rxjs';
import { io, Socket } from 'socket.io-client';
import { getWebSocketUrl } from '../utils/get-base-address';

export interface NotePayload {
  id: number;
  content: string;
  posX: number;
  posY: number;
  zIndex: number;
  householdId: number;
  appUserId: number;
  AppUser?: { id: number; username: string };
  createdAt: string;
  updatedAt: string;
  noteColor?: string;
  headerColor?: string | null;
  textDirection?: 'ltr' | 'rtl' | 'auto';
  textSize?: number;
  isBold?: boolean;
  isUnderline?: boolean;
  textColor?: string;
}

@Injectable({ providedIn: 'root' })
export class SocketService implements OnDestroy {
  private socket: Socket | null = null;

  noteCreated$ = new Subject<NotePayload>();
  noteUpdated$ = new Subject<NotePayload>();
  noteDeleted$ = new Subject<number>();

  connect(householdId: number, token: string): void {
    if (this.socket?.connected) return;

    this.socket = io(getWebSocketUrl(), {
      transports: ['polling', 'websocket'],
      auth: { token },
      reconnection: true,
      reconnectionDelay: 2000,
      reconnectionAttempts: 10,
    });

    this.socket.on('connect_error', () => { /* silent – backend may not be running */ });

    this.socket.on('connect', () => {
      this.socket!.emit('join-household', householdId);
    });

    this.socket.on('note:created', (note: NotePayload) => this.noteCreated$.next(note));
    this.socket.on('note:updated', (note: NotePayload) => this.noteUpdated$.next(note));
    this.socket.on('note:deleted', (id: number) => this.noteDeleted$.next(id));
  }

  disconnect(): void {
    this.socket?.disconnect();
    this.socket = null;
  }

  ngOnDestroy(): void {
    this.disconnect();
  }
}
