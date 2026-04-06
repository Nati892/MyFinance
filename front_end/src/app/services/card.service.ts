import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { AppAuthService } from './app-auth.service';
import { getApiUrl } from '../utils/get-base-address';

export interface Card {
  id: number;
  lastFourDigits: string;
  nickname: string | null;
  bankName: string | null;
  cardType: 'credit' | 'debit' | null;
  householdId: number;
}

@Injectable({ providedIn: 'root' })
export class CardService {
  private apiUrl = getApiUrl();

  constructor(
    private http: HttpClient,
    private appAuthService: AppAuthService
  ) {}

  private getHeaders(): HttpHeaders {
    const token = this.appAuthService.getToken();
    return new HttpHeaders({
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    });
  }

  getCards(householdId: number): Observable<{ success: boolean; cards: Card[] }> {
    const params = new HttpParams().set('householdId', householdId.toString());
    return this.http.get<{ success: boolean; cards: Card[] }>(
      `${this.apiUrl}/app/cards`,
      { headers: this.getHeaders(), params }
    );
  }

  createCard(data: { lastFourDigits: string; nickname?: string; bankName?: string; cardType?: string; householdId: number }): Observable<{ success: boolean; card: Card }> {
    return this.http.post<{ success: boolean; card: Card }>(
      `${this.apiUrl}/app/cards`,
      data,
      { headers: this.getHeaders() }
    );
  }

  updateCard(id: number, data: Partial<{ lastFourDigits: string; nickname: string; bankName: string; cardType: string }>): Observable<{ success: boolean; card: Card }> {
    return this.http.put<{ success: boolean; card: Card }>(
      `${this.apiUrl}/app/cards/${id}`,
      data,
      { headers: this.getHeaders() }
    );
  }

  deleteCard(id: number): Observable<{ success: boolean }> {
    return this.http.delete<{ success: boolean }>(
      `${this.apiUrl}/app/cards/${id}`,
      { headers: this.getHeaders() }
    );
  }
}
