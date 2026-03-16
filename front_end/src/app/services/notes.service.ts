import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { AppAuthService } from './app-auth.service';
import { getApiUrl } from '../utils/get-base-address';

export interface Note {
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
  // Styling fields
  noteColor: string;
  headerColor: string | null;
  textDirection: 'ltr' | 'rtl' | 'auto';
  textSize: number;
  isBold: boolean;
  isUnderline: boolean;
  textColor: string;
}

@Injectable({ providedIn: 'root' })
export class NotesService {
  private apiUrl = getApiUrl();

  constructor(private http: HttpClient, private appAuthService: AppAuthService) {}

  private getHeaders(): HttpHeaders {
    const token = this.appAuthService.getToken();
    return new HttpHeaders({ Authorization: `Bearer ${token}` });
  }

  list(householdId: number): Observable<{ success: boolean; notes: Note[] }> {
    const params = new HttpParams().set('householdId', householdId.toString());
    return this.http.get<any>(`${this.apiUrl}/app/notes`, { headers: this.getHeaders(), params });
  }

  create(data: { content: string; posX: number; posY: number; zIndex: number; householdId: number }): Observable<{ success: boolean; note: Note }> {
    return this.http.post<any>(`${this.apiUrl}/app/notes`, data, { headers: this.getHeaders() });
  }

  update(id: number, data: Partial<{
    content: string;
    posX: number;
    posY: number;
    zIndex: number;
    noteColor: string;
    headerColor: string | null;
    textDirection: 'ltr' | 'rtl' | 'auto';
    textSize: number;
    isBold: boolean;
    isUnderline: boolean;
    textColor: string;
  }>): Observable<{ success: boolean; note: Note }> {
    return this.http.put<any>(`${this.apiUrl}/app/notes/${id}`, data, { headers: this.getHeaders() });
  }

  delete(id: number): Observable<{ success: boolean }> {
    return this.http.delete<any>(`${this.apiUrl}/app/notes/${id}`, { headers: this.getHeaders() });
  }
}
