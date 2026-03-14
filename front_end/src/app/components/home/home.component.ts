import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient, HttpClientModule } from '@angular/common/http';

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [CommonModule, HttpClientModule],
  templateUrl: './home.component.html',
  styleUrls: ['./home.component.css']
})
export class HomeComponent {
  welcomeMessage = 'Welcome to the Dashboard';
  deviceInfo: any = {};
  locationInfo: any = null;
  ipInfo: any = null;
  ipLocationInfo: any = null;
  mediaInfo: any = null;
  motionInfo: any = null;
  orientationInfo: any = null;
  notificationPermission: string = '';
  fingerprintInfo: any = {};

  constructor(private http: HttpClient) {}

  ngOnInit(): void {
    this.collectBasicDeviceInfo();
    this.getIPInfo();
    this.getLocationInfo();
    this.getMediaDevices();
    this.getMotionInfo();
    this.getNotificationPermission();
    this.getAdvancedFingerprint();
  }

  // Get IP and location from IP
  private async getIPInfo(): Promise<void> {
    try {
      // Get basic IP info
      const ipResponse = await fetch('https://api.ipify.org?format=json');
      const ipData = await ipResponse.json();
      
      // Get detailed IP location info
      const locationResponse = await fetch(`https://ipapi.co/${ipData.ip}/json/`);
      const locationData = await locationResponse.json();
      
      this.ipInfo = {
        ip:' 212.179.203.114', //ipData.ip,
        type: this.getIPType(ipData.ip)
      };

      this.ipLocationInfo = {
        city: locationData.city,
        region: locationData.region,
        country: locationData.country_name,
        countryCode: locationData.country_code,
        latitude: locationData.latitude,
        longitude: locationData.longitude,
        timezone: locationData.timezone,
        isp: locationData.org,
        asn: locationData.asn,
        postal: locationData.postal,
        accuracy: 'City level (IP-based)'
      };
    } catch (error) {
      console.error('Error getting IP info:', error);
      this.ipInfo = { error: 'Unable to fetch IP information' };
      this.ipLocationInfo = { error: 'Unable to fetch IP location' };
    }
  }

  private getIPType(ip: string): string {
    if (ip.includes(':')) return 'IPv6';
    if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) return 'IPv4 (Private)';
    return 'IPv4 (Public)';
  }

  private collectBasicDeviceInfo(): void {
    // User Agent and Browser Info
    const userAgent = navigator.userAgent;
    const platform = navigator.platform;
    const language = navigator.language;
    const languages = navigator.languages;
    const cookieEnabled = navigator.cookieEnabled;
    const onLine = navigator.onLine;
    const doNotTrack = navigator.doNotTrack;

    // Screen Information
    const screenWidth = screen.width;
    const screenHeight = screen.height;
    const screenColorDepth = screen.colorDepth;
    const screenPixelDepth = screen.pixelDepth;
    const availWidth = screen.availWidth;
    const availHeight = screen.availHeight;

    // Window/Viewport Information
    const windowWidth = window.innerWidth;
    const windowHeight = window.innerHeight;
    const screenX = window.screenX;
    const screenY = window.screenY;

    // Time Zone
    const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    const timezoneOffset = new Date().getTimezoneOffset();

    // Hardware Info (limited)
    const hardwareConcurrency = navigator.hardwareConcurrency;
    const maxTouchPoints = navigator.maxTouchPoints;

    // Connection Info (if supported)
    const connection = (navigator as any).connection || (navigator as any).mozConnection || (navigator as any).webkitConnection;
    let connectionInfo = null;
    if (connection) {
      connectionInfo = {
        effectiveType: connection.effectiveType,
        downlink: connection.downlink,
        rtt: connection.rtt,
        saveData: connection.saveData
      };
    }

    // Referrer
    const referrer = document.referrer;

    // Browser Features Detection
    const features = {
      webGL: !!window.WebGLRenderingContext,
      webGL2: !!window.WebGL2RenderingContext,
      webRTC: !!(window as any).RTCPeerConnection,
      localStorage: !!window.localStorage,
      sessionStorage: !!window.sessionStorage,
      indexedDB: !!window.indexedDB,
      webWorkers: !!window.Worker,
      serviceWorkers: 'serviceWorker' in navigator,
      webAssembly: 'WebAssembly' in window,
      touchSupport: 'ontouchstart' in window
    };

    this.deviceInfo = {
      userAgent,
      platform,
      language,
      languages,
      cookieEnabled,
      onLine,
      doNotTrack,
      screen: {
        width: screenWidth,
        height: screenHeight,
        colorDepth: screenColorDepth,
        pixelDepth: screenPixelDepth,
        availWidth,
        availHeight
      },
      viewport: {
        width: windowWidth,
        height: windowHeight,
        screenX,
        screenY
      },
      timeZone,
      timezoneOffset,
      hardwareConcurrency,
      maxTouchPoints,
      connection: connectionInfo,
      referrer,
      features
    };
  }

  // Location (requires permission)
  private async getLocationInfo(): Promise<void> {
    if ('geolocation' in navigator) {
      try {
        const position = await new Promise<GeolocationPosition>((resolve, reject) => {
          navigator.geolocation.getCurrentPosition(resolve, reject, {
            enableHighAccuracy: true,
            timeout: 10000,
            maximumAge: 60000
          });
        });

        this.locationInfo = {
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
          accuracy: position.coords.accuracy,
          altitude: position.coords.altitude,
          altitudeAccuracy: position.coords.altitudeAccuracy,
          heading: position.coords.heading,
          speed: position.coords.speed,
          timestamp: new Date(position.timestamp).toLocaleString()
        };
      } catch (error: any) {
        this.locationInfo = { error: error.message || 'Location access denied' };
      }
    } else {
      this.locationInfo = { error: 'Geolocation not supported' };
    }
  }

  // Camera/Microphone (requires permission)
  private async getMediaDevices(): Promise<void> {
    if ('mediaDevices' in navigator) {
      try {
        const devices = await navigator.mediaDevices.enumerateDevices();
        this.mediaInfo = {
          audioInputs: devices.filter(d => d.kind === 'audioinput').length,
          videoInputs: devices.filter(d => d.kind === 'videoinput').length,
          audioOutputs: devices.filter(d => d.kind === 'audiooutput').length,
          devices: devices.map(d => ({
            kind: d.kind,
            label: d.label || 'Unknown device',
            deviceId: d.deviceId ? 'Available' : 'No ID'
          }))
        };
      } catch (error: any) {
        this.mediaInfo = { error: error.message || 'Media devices access failed' };
      }
    } else {
      this.mediaInfo = { error: 'Media devices not supported' };
    }
  }

  // Motion/Orientation Sensors (requires permission on iOS 13+)
  private async getMotionInfo(): Promise<void> {
    if ('DeviceMotionEvent' in window) {
      // Request permission on iOS
      if (typeof (DeviceMotionEvent as any).requestPermission === 'function') {
        try {
          const permission = await (DeviceMotionEvent as any).requestPermission();
          if (permission === 'granted') {
            this.setupMotionListeners();
          } else {
            this.motionInfo = { error: 'Motion permission denied' };
          }
        } catch (error: any) {
          this.motionInfo = { error: error.message || 'Motion permission request failed' };
        }
      } else {
        this.setupMotionListeners();
      }
    } else {
      this.motionInfo = { error: 'Device motion not supported' };
    }
  }

  private setupMotionListeners(): void {
    this.motionInfo = { status: 'Listening for motion...' };
    this.orientationInfo = { status: 'Listening for orientation...' };

    const motionHandler = (event: DeviceMotionEvent) => {
      this.motionInfo = {
        acceleration: {
          x: event.acceleration?.x?.toFixed(2),
          y: event.acceleration?.y?.toFixed(2),
          z: event.acceleration?.z?.toFixed(2)
        },
        accelerationIncludingGravity: {
          x: event.accelerationIncludingGravity?.x?.toFixed(2),
          y: event.accelerationIncludingGravity?.y?.toFixed(2),
          z: event.accelerationIncludingGravity?.z?.toFixed(2)
        },
        rotationRate: {
          alpha: event.rotationRate?.alpha?.toFixed(2),
          beta: event.rotationRate?.beta?.toFixed(2),
          gamma: event.rotationRate?.gamma?.toFixed(2)
        },
        interval: event.interval
      };
    };

    const orientationHandler = (event: DeviceOrientationEvent) => {
      this.orientationInfo = {
        alpha: event.alpha?.toFixed(2), // Z axis
        beta: event.beta?.toFixed(2),   // X axis
        gamma: event.gamma?.toFixed(2), // Y axis
        absolute: event.absolute
      };
    };

    window.addEventListener('devicemotion', motionHandler);
    window.addEventListener('deviceorientation', orientationHandler);

    // Remove listeners after 30 seconds to avoid continuous updates
    setTimeout(() => {
      window.removeEventListener('devicemotion', motionHandler);
      window.removeEventListener('deviceorientation', orientationHandler);
    }, 30000);
  }

  // Notifications (requires permission)
  private async getNotificationPermission(): Promise<void> {
    if ('Notification' in window) {
      try {
        const permission = await Notification.requestPermission();
        this.notificationPermission = permission;
      } catch (error) {
        this.notificationPermission = 'Error requesting permission';
      }
    } else {
      this.notificationPermission = 'Not supported';
    }
  }

  private getAdvancedFingerprint(): void {
    // Canvas fingerprinting
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d')!;
    ctx.textBaseline = 'top';
    ctx.font = '14px Arial';
    ctx.fillText('Device fingerprint', 2, 2);
    const canvasFingerprint = canvas.toDataURL();

    // WebGL fingerprinting
    const webglCanvas = document.createElement('canvas');
    const gl = webglCanvas.getContext('webgl');
    let webglInfo = {};
    if (gl) {
      webglInfo = {
        vendor: gl.getParameter(gl.VENDOR),
        renderer: gl.getParameter(gl.RENDERER),
        version: gl.getParameter(gl.VERSION),
        shadingLanguageVersion: gl.getParameter(gl.SHADING_LANGUAGE_VERSION)
      };
    }

    // Audio context fingerprinting
    let audioFingerprint = null;
    try {
      const audioContext = new (window.AudioContext || (window as any).webkitAudioContext)();
      const oscillator = audioContext.createOscillator();
      const analyser = audioContext.createAnalyser();
      const gainNode = audioContext.createGain();
      oscillator.connect(analyser);
      analyser.connect(gainNode);
      gainNode.connect(audioContext.destination);
      audioFingerprint = analyser.frequencyBinCount;
      audioContext.close();
    } catch (error) {
      audioFingerprint = 'Audio context not available';
    }

    // Font detection (basic)
    const testFonts = ['Arial', 'Times New Roman', 'Courier New', 'Helvetica', 'Georgia', 'Verdana'];
    const availableFonts = testFonts.filter(font => {
      const testElement = document.createElement('span');
      testElement.style.fontFamily = font;
      testElement.style.fontSize = '12px';
      testElement.textContent = 'Test';
      testElement.style.position = 'absolute';
      testElement.style.left = '-9999px';
      document.body.appendChild(testElement);
      const width = testElement.offsetWidth;
      document.body.removeChild(testElement);
      return width > 0;
    });

    this.fingerprintInfo = {
      canvasFingerprint: canvasFingerprint.slice(-50),
      webglInfo,
      audioFingerprint,
      availableFonts,
      pixelRatio: window.devicePixelRatio,
      hasSessionStorage: !!window.sessionStorage,
      hasLocalStorage: !!window.localStorage,
      hasIndexedDB: !!window.indexedDB
    };
  }
}