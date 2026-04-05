import type { Metadata } from 'next';
import { Plus_Jakarta_Sans, DM_Sans } from 'next/font/google';
import './globals.css';
import { LocaleProvider } from '@/i18n';

const plusJakarta = Plus_Jakarta_Sans({
  subsets: ['latin'],
  variable: '--font-display',
  display: 'swap',
});

const dmSans = DM_Sans({
  subsets: ['latin'],
  variable: '--font-body',
  display: 'swap',
});

const siteUrl = 'https://topscoreapp.ai';

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: 'TopScore AI — #1 AI-Powered Learning App for Kenyan Students | CBC, KCSE & IGCSE',
    template: '%s | TopScore AI',
  },
  description:
    'TopScore AI is Kenya\'s leading AI tutor for students. Master CBC, KCSE, and IGCSE with instant homework help, past papers, smart study tools, and AI-graded compositions. Free on Android & iOS.',
  keywords: [
    'TopScore AI', 'AI tutor Kenya', 'KCSE revision app', 'CBC learning app', 
    'IGCSE revision Kenya', 'Kenya education AI', 'AI homework help', 
    'KCSE past papers 2026', 'CBC Grade 9 resources', 'AI study assistant',
    'Kenya school portal', 'Form 4 revision notes', 'Insha AI grading',
    'English composition AI', 'Kenya student study app',
  ],
  authors: [{ name: 'TopScore AI', url: siteUrl }],
  creator: 'TopScore AI',
  publisher: 'TopScore AI',
  applicationName: 'TopScore AI',
  category: 'education',
  classification: 'Education Application',
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-image-preview': 'large',
      'max-snippet': -1,
      'max-video-preview': -1,
    },
  },
  openGraph: {
    type: 'website',
    locale: 'en_KE',
    url: siteUrl,
    siteName: 'TopScore AI',
    title: 'TopScore AI — Kenya\'s #1 AI Tutor for CBC, KCSE & IGCSE',
    description:
      'Master your exams with the most powerful AI tutor in Kenya. Get instant feedback on English & Kiswahili compositions, solve complex maths, and access thousands of resources.',
    images: [
      {
        url: '/og-image.png',
        width: 1200,
        height: 630,
        alt: 'TopScore AI — AI-Powered Learning for Kenyan Students',
        type: 'image/png',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    site: '@TopScoreAI',
    creator: '@TopScoreAI',
    title: 'TopScore AI — Kenya\'s #1 AI Tutor for Kenyan Students',
    description:
      'Personalized AI tutoring for CBC & KCSE students. Free on Android, iOS & Web.',
    images: ['/og-image.png'],
  },
  alternates: {
    canonical: siteUrl,
    languages: {
      'en-KE': siteUrl,
    },
  },
  icons: {
    icon: [
      { url: '/logo.png', type: 'image/png' },
    ],
    apple: '/logo.png',
    shortcut: '/logo.png',
  },
  verification: {
    google: '83231e9246a44c2fbfebd62728e1f204',
  },
  other: {
    'mobile-web-app-capable': 'yes',
    'apple-mobile-web-app-capable': 'yes',
    'apple-mobile-web-app-status-bar-style': 'default',
    'apple-mobile-web-app-title': 'TopScore AI',
    'format-detection': 'telephone=no',
    'geo.region': 'KE',
    'geo.placename': 'Kenya',
    'ICBM': '-1.286389, 36.817223',
  },
};

const organizationSchema = {
  '@context': 'https://schema.org',
  '@type': 'Organization',
  '@id': `${siteUrl}/#organization`,
  name: 'TopScore AI',
  url: siteUrl,
  logo: {
    '@type': 'ImageObject',
    url: `${siteUrl}/logo.png`,
    width: 512,
    height: 512,
  },
  sameAs: [
    'https://twitter.com/TopScoreAI',
    'https://play.google.com/store/apps/details?id=com.topscoreapp.ai',
  ],
  description: 'Kenyan premium AI-powered education platform supporting CBC, IGCSE & KCSE learners.',
  areaServed: { '@type': 'Country', name: 'Kenya' },
  knowsAbout: ['CBC Curriculum', '8-4-4 Curriculum', 'IGCSE Curriculum', 'KCSE Revision', 'Exam Preparation', 'AI Tutoring'],
};

const websiteSchema = {
  '@context': 'https://schema.org',
  '@type': 'WebSite',
  '@id': `${siteUrl}/#website`,
  name: 'TopScore AI',
  url: siteUrl,
  potentialAction: {
    '@type': 'SearchAction',
    target: { '@type': 'EntryPoint', urlTemplate: `${siteUrl}/?q={search_term_string}` },
    'query-input': 'required name=search_term_string',
  },
};

const softwareAppSchema = {
  '@context': 'https://schema.org',
  '@type': 'SoftwareApplication',
  '@id': `${siteUrl}/#app`,
  name: 'TopScore AI',
  applicationCategory: 'EducationalApplication',
  operatingSystem: 'Android, iOS, Web',
  url: siteUrl,
  downloadUrl: 'https://play.google.com/store/apps/details?id=com.topscoreapp.ai',
  offers: {
    '@type': 'Offer',
    price: '0',
    priceCurrency: 'KES',
    description: '7-day free trial for new users',
  },
  aggregateRating: {
    '@type': 'AggregateRating',
    ratingValue: '4.8',
    ratingCount: '1200',
    bestRating: '5',
  },
  screenshot: `${siteUrl}/og-image.png`,
  featureList: [
    '24/7 AI Tutor with Live Voice',
    'KCSE, CBC & IGCSE Past Papers',
    'AI-Graded English Compositions \u0026 Swahili Insha',
    'AI Flashcard Generator',
    'Smart Study Timetable',
    'Scientific Calculator',
    'Virtual Science Lab Experiments',
    'Offline Study Mode',
    'Personalized Progress Tracking',
  ],
};

import BackToTop from '@/components/BackToTop';
import CookieConsent from '@/components/CookieConsent';
import Analytics from '@/components/Analytics';
import { ThemeProvider } from "@/components/ThemeProvider";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${plusJakarta.variable} ${dmSans.variable}`} suppressHydrationWarning>
      <head>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(organizationSchema) }}
        />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(websiteSchema) }}
        />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(softwareAppSchema) }}
        />
        {/* Enable CSS View Transitions for smooth page navigation */}
        <style>{`
          @view-transition { navigation: auto; }

          ::view-transition-old(root) {
            animation: 220ms cubic-bezier(0.4, 0, 1, 1) both vtFadeOut;
          }
          ::view-transition-new(root) {
            animation: 320ms cubic-bezier(0, 0, 0.2, 1) 80ms both vtFadeIn;
          }
          @keyframes vtFadeOut {
            from { opacity: 1; transform: translateY(0); }
            to   { opacity: 0; transform: translateY(-8px); }
          }
          @keyframes vtFadeIn {
            from { opacity: 0; transform: translateY(12px); }
            to   { opacity: 1; transform: translateY(0); }
          }
          @media (prefers-reduced-motion: reduce) {
            ::view-transition-old(root),
            ::view-transition-new(root) { animation: none; }
          }
        `}</style>
      </head>
      <body>
        <ThemeProvider
          attribute="class"
          defaultTheme="system"
          enableSystem
          disableTransitionOnChange
        >
          {children}
          <CookieConsent />
        </ThemeProvider>
        <BackToTop />
        <Analytics />
      </body>
    </html>
  );
}
