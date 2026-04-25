import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { AppAuthService } from './app-auth.service';
import { getApiUrl } from '../utils/get-base-address';

export interface AttachmentCategory {
  name: string;
  color: string;
}

export interface AttachmentTransaction {
  id: number;
  amount: number;
  dateTime: string;
  description: string;
  category: AttachmentCategory | null;
}

export interface AttachmentAppUser {
  id: number;
  username: string;
}

export interface Attachment {
  id: number;
  filename: string;
  originalFilename: string;
  mimeType: string;
  size: number;
  isImage: boolean;
  createdAt: string;
  fileUrl: string;
  thumbUrl: string | null;
  appUser: AttachmentAppUser;
  expense: AttachmentTransaction | null;
  income: AttachmentTransaction | null;
}

@Injectable({ providedIn: 'root' })
export class AttachmentsService {
  private apiUrl = getApiUrl() + '/app/attachments';

  constructor(private http: HttpClient, private appAuthService: AppAuthService) {}

  private getHeaders(): HttpHeaders {
    const token = this.appAuthService.getToken();
    return new HttpHeaders({ Authorization: `Bearer ${token}` });
  }

  listForHousehold(householdId: number): Observable<{ success: boolean; attachments: Attachment[] }> {
    return this.http.get<{ success: boolean; attachments: Attachment[] }>(
      `${this.apiUrl}/household/${householdId}`,
      { headers: this.getHeaders() }
    );
  }

  delete(id: number): Observable<{ success: boolean }> {
    return this.http.delete<{ success: boolean }>(
      `${this.apiUrl}/${id}`,
      { headers: this.getHeaders() }
    );
  }
}
