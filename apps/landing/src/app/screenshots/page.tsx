import type { Metadata } from 'next';
import Nav from '@/components/Nav';
import Screenshots from '@/components/Screenshots';
import Footer from '@/components/Footer';
import JsonLd from '@/components/JsonLd';
import Breadcrumbs from '@/components/Breadcrumbs';

export const metadata: Metadata = {
    title: 'App Preview',
    description: 'Explore the TopScore AI mobile app interface — designed for student focus, premium learning, and powerful AI tools.',
};

const schema = {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: 'App Previews | TopScore AI',
    url: 'https://topscoreapp.ai/screenshots',
    isPartOf: { '@id': 'https://topscoreapp.ai/#website' },
};

export default function ScreenshotsPage() {
    return (
        <main>
            <JsonLd data={schema} />
            <Nav />
            <div className="container mx-auto px-4 pt-32 pb-20">
                <Breadcrumbs items={[{ label: 'Screenshots' }]} />
                <div className="text-center mb-16">
                    <h1 className="text-4xl md:text-5xl font-bold mb-6">Designed for <span className="text-primary">Excellence</span></h1>
                    <p className="text-muted-foreground text-lg max-w-2xl mx-auto leading-relaxed">
                        TopScore AI is more than just a tutoring app. It is a premium learning experience, built from the ground up to empower students and learners across Kenya.
                    </p>
                </div>
                <Screenshots />
            </div>
            <Footer />
        </main>
    );
}
