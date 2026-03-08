import type { Metadata } from 'next';
import Nav from '@/components/Nav';
import Hero from '@/components/Hero';
import TrustedBy from '@/components/TrustedBy';
import Features from '@/components/Features';
import Screenshots from '@/components/Screenshots';
import HowItWorks from '@/components/HowItWorks';
import Testimonials from '@/components/Testimonials';
import FAQ from '@/components/FAQ';
import Newsletter from '@/components/Newsletter';
import CtaBanner from '@/components/CtaBanner';
import Footer from '@/components/Footer';
import JsonLd from '@/components/JsonLd';

export const metadata: Metadata = {
  title: 'TopScore AI — Smart AI Learning platform for Kenyan Students',
  description:
    'AI-powered tutoring, CBC & KCSE study resources, past papers, smart study tools, detailed progress tracking, and offline mode. Free to download.',
  openGraph: {
    title: 'TopScore AI — Smart AI Learning platform for Kenyan Students',
    description:
      'The #1 AI-powered tutoring and study platform for CBC & KCSE. Snap photos, chat with books, and ace your exams. Free to download.',
    url: 'https://topscoreapp.ai',
    images: [{ url: '/og-image.png', width: 1200, height: 630 }],
  },
  alternates: { canonical: 'https://topscoreapp.ai' },
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
    <main>
      <JsonLd data={softwareSchema} />
      <Nav />
      <Hero />
      <TrustedBy />
      <Features />
      <Screenshots />
      <HowItWorks />
      <Testimonials />
      <FAQ />
      <Newsletter />
      <CtaBanner />
      <Footer />
    </main>
  );
}
