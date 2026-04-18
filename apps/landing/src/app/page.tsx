import { Metadata } from 'next';
import Link from 'next/link';
import { Button } from '@/components/ui/button';
import Nav from '@/components/Nav';
import Hero from '@/components/Hero';
import TrustedBy from '@/components/TrustedBy';
import ActiveVoiceShowcase from '@/components/ActiveVoiceShowcase';
import Footer from '@/components/Footer';
import JsonLd from '@/components/JsonLd';
import Safety from '@/components/Safety';
import BentoFeatures from '@/components/BentoFeatures';

export const metadata: Metadata = {
  alternates: { canonical: 'https://topscoreapp.ai' },
};

const organizationSchema = {
  '@context': 'https://schema.org',
  '@type': 'Organization',
  name: 'TopScore AI',
  url: 'https://topscoreapp.ai',
  logo: 'https://topscoreapp.ai/logo.png',
  sameAs: [],
  description:
    'AI-powered tutoring and study resources for Kenyan students — CBC, IGCSE & KCSE.',
};

const softwareSchema = {
  '@context': 'https://schema.org',
  '@type': 'SoftwareApplication',
  name: 'TopScore AI',
  url: 'https://topscoreapp.ai',
  logo: 'https://topscoreapp.ai/logo.png',
  description: 'AI-powered tutoring, study resources, and smart study tools for Kenyan students.',
  applicationCategory: 'EducationalApplication',
  operatingSystem: 'iOS, Android, Web',
  offers: {
    '@type': 'Offer',
    price: '0',
    priceCurrency: 'KES',
  },
  screenshot: 'https://topscoreapp.ai/og-image.png',
};

export default function Home() {
  return (
    <main className="min-h-screen flex flex-col" suppressHydrationWarning>
      <JsonLd data={organizationSchema} />
      <JsonLd data={softwareSchema} />
      <Nav />
      <div className="flex-grow flex flex-col">
        <Hero />
        <TrustedBy />
        <BentoFeatures />
        <ActiveVoiceShowcase />
        <Safety />
      </div>
      <Footer />
    </main>
  );
}
