import { Metadata } from 'next';
import Nav from '@/components/Nav';
import Hero from '@/components/Hero';
import Curriculum from '../components/Curriculum';
import Features from '@/components/Features';
import Interactive from '../components/Interactive';
import Testimonials from '@/components/Testimonials';
import Pricing from '@/components/Pricing';
import FAQ from '@/components/FAQ';
import TechStack from '../components/TechStack';
import TrustedBy from '../components/TrustedBy';
import Screenshots from '../components/Screenshots';
import Mission from '@/components/Mission';
import MobileStickyCTA from '@/components/MobileStickyCTA';

import Footer from '@/components/Footer';
import JsonLd from '@/components/JsonLd';

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
    <main className="min-h-screen bg-white" suppressHydrationWarning>
      <JsonLd data={organizationSchema} />
      <JsonLd data={softwareSchema} />
      <Nav />
      <Hero />
      <TrustedBy />
      <Curriculum />
      <Features />
      <Screenshots />
      <Mission />
      
      {/* Multimodal Showcase Section is handled within the new UI components or inline if needed */}
      <Interactive />
      <Testimonials />
      <Pricing />
      <FAQ />
      <TechStack />
      <Footer />
      <MobileStickyCTA />
    </main>
  );
}

