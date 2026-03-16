import { Injectable, Inject, PLATFORM_ID } from '@angular/core';
import { isPlatformBrowser } from '@angular/common';
import { TranslateService } from '@ngx-translate/core';
import { BehaviorSubject } from 'rxjs';

export type Lang = 'en' | 'he';

@Injectable({ providedIn: 'root' })
export class LanguageService {
  private langSubject = new BehaviorSubject<Lang>(this.getSavedLang());
  lang$ = this.langSubject.asObservable();

  constructor(
    private translate: TranslateService,
    @Inject(PLATFORM_ID) private platformId: object
  ) {
    this.translate.addLangs(['en', 'he']);
    this.translate.setDefaultLang('en');
    this.applyLang(this.langSubject.value);
  }

  get currentLang(): Lang {
    return this.langSubject.value;
  }

  setLang(lang: Lang): void {
    this.langSubject.next(lang);
    localStorage.setItem('app-lang', lang);
    this.applyLang(lang);
  }

  toggleLang(): void {
    this.setLang(this.currentLang === 'en' ? 'he' : 'en');
  }

  private applyLang(lang: Lang): void {
    this.translate.use(lang);
    if (isPlatformBrowser(this.platformId)) {
      const html = document.documentElement;
      html.setAttribute('lang', lang);
      html.setAttribute('dir', lang === 'he' ? 'rtl' : 'ltr');
    }
  }

  private getSavedLang(): Lang {
    try {
      const saved = localStorage.getItem('app-lang');
      if (saved === 'he' || saved === 'en') return saved;
    } catch {}
    return 'en';
  }
}
