import type { Metadata } from 'next';
import dynamic from 'next/dynamic';
import Nav from '@/components/Nav';
import Hero from '@/components/Hero';
import TrustedBy from '@/components/TrustedBy';
import Features from '@/components/Features';
import JsonLd from '@/components/JsonLd';

const Screenshots = dynamic(() => import('@/components/Screenshots'));
const HowItWorks = dynamic(() => import('@/components/HowItWorks'));
const VideoGallery = dynamic(() => import('@/components/VideoGallery'));
const Pricing = dynamic(() => import('@/components/Pricing'));
const Testimonials = dynamic(() => import('@/components/Testimonials'));
const FAQ = dynamic(() => import('@/components/FAQ'));
const Contact = dynamic(() => import('@/components/Contact'));
const Newsletter = dynamic(() => import('@/components/Newsletter'));
const CtaBanner = dynamic(() => import('@/components/CtaBanner'));
const Footer = dynamic(() => import('@/components/Footer'));

export const metadata: Metadata = {
  title: 'TopScore AI — The #1 Smart Learning App for Kenyan Students',
  description:
    'Experience vibrant, playful, and intelligent AI-powered tutoring, CBC & KCSE study resources, smart tools, detailed tracking, and offline modes. Upgrade your learning journey today.',
  openGraph: {
    title: 'TopScore AI — The #1 Smart Learning App for Kenyan Students',
    description:
      'Experience vibrant, playful, and intelligent AI-powered tutoring, CBC & KCSE study resources. Snap photos, chat with books, and ace your exams. Free to download with Premium options.',
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
      <HowItWorks />
      <VideoGallery />
      <Screenshots />
      <Pricing />
      <Testimonials />
      <FAQ />
      <Contact />
      <Newsletter />
      <CtaBanner />
      <Footer />
    </main>
  );
}

