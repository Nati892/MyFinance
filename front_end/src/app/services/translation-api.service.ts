import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable, of } from 'rxjs';
import { map, catchError } from 'rxjs/operators';

@Injectable({ providedIn: 'root' })
export class TranslationApiService {
  constructor(private http: HttpClient) {}

  translate(text: string, from: 'en' | 'he', to: 'en' | 'he'): Observable<string> {
    if (!text.trim()) return of('');
    const langpair = `${from}|${to}`;
    return this.http
      .get<any>('https://api.mymemory.translated.net/get', {
        params: { q: text, langpair },
      })
      .pipe(
        map((res) => res?.responseData?.translatedText || ''),
        catchError(() => of(''))
      );
  }
}
