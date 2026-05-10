import type { Metadata } from 'next';
import Nav from '@/components/Nav';
import Testimonials from '@/components/Testimonials';
import Footer from '@/components/Footer';
import JsonLd from '@/components/JsonLd';
import Safety from '@/components/Safety';
import ReviewsCta from '@/components/ReviewsCta';

export const metadata: Metadata = {
    title: 'Reviews',
    description: 'See what students, parents, and teachers across Kenya are saying about TopScore AI.',
};

const schema = {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: 'Student Reviews | TopScore AI',
    url: 'https://topscoreapp.ai/reviews',
    isPartOf: { '@id': 'https://topscoreapp.ai/#website' },
};

export default function ReviewsPage() {
    return (
        <main className="min-h-screen" suppressHydrationWarning>
            <JsonLd data={schema} />
            <Nav />
            <div className="container mx-auto px-6 pt-32 pb-24">
                <div className="max-w-7xl mx-auto">
                    <Testimonials />
                    <Safety />
                    <ReviewsCta />
                </div>
            </div>
            <Footer />
        </main>
    );
}
