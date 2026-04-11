import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ApkManagementService } from '../../services/apk-management.service';
import { getWebSocketUrl } from '../../utils/get-base-address';

@Component({
    selector: 'app-apk-management',
    standalone: true,
    imports: [CommonModule],
    templateUrl: './apk-management.component.html',
    styleUrls: ['./apk-management.component.css']
})
export class ApkManagementComponent implements OnInit {
    currentVersion: number | null = null;
    loading = false;
    error = '';
    copied = false;
    copiedLink = false;

    readonly managerToken = 'household-manager-api-token';

    get serverUrl(): string {
        return getWebSocketUrl();
    }

    get publicDownloadLink(): string {
        return `${this.serverUrl}/apk/download`;
    }

    get curlCommand(): string {
        return `curl -X POST \\
  -H "Authorization: Bearer ${this.managerToken}" \\
  -F "apk=@./app-release.apk" \\
  ${this.serverUrl}/api/apk/upload`;
    }

    constructor(private apkService: ApkManagementService) { }

    ngOnInit(): void {
        this.loadLatest();
    }

    loadLatest(): void {
        this.loading = true;
        this.error = '';

        this.apkService.getLatest().subscribe({
            next: (res) => {
                this.currentVersion = res.version;
                this.loading = false;
            },
            error: (err) => {
                if (err.status === 404) {
                    this.currentVersion = null;
                    this.error = '';
                } else {
                    this.error = 'Failed to load APK info.';
                }
                this.loading = false;
            }
        });
    }

    copyToClipboard(): void {
        navigator.clipboard.writeText(this.curlCommand).then(() => {
            this.copied = true;
            setTimeout(() => this.copied = false, 2000);
        });
    }

    copyLinkToClipboard(): void {
        navigator.clipboard.writeText(this.publicDownloadLink).then(() => {
            this.copiedLink = true;
            setTimeout(() => this.copiedLink = false, 2000);
        });
    }
}
