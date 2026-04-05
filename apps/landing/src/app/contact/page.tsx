'use client';
import { useLocale } from '@/i18n';
import Nav from '@/components/Nav';
import Footer from '@/components/Footer';
import AnimatedSection from '@/components/AnimatedSection';
import { Mail, Phone, MessageCircle, Facebook, Linkedin, ExternalLink, Twitter, Instagram } from 'lucide-react';
import styles from './Contact.module.css';

const contactMethods = [
    { icon: <MessageCircle />, key: 'contact.whatsapp', href: 'https://wa.me/254717273230', color: '#25D366' },
    { icon: <Phone />, key: 'contact.telephone', href: 'tel:0717273230', color: '#3b82f6' },
    { icon: <Mail />, key: 'contact.email', href: 'mailto:support@topscoreapp.ai', color: '#ef4444' },
    { icon: <Facebook />, key: 'contact.facebook', href: 'https://facebook.com/TopScoreAI', color: '#1877F2' },
    { icon: <Linkedin />, key: 'contact.linkedin', href: 'https://linkedin.com/company/topscore-ai', color: '#0A66C2' },
    { icon: <Twitter />, key: 'contact.twitter', href: 'https://twitter.com/TopScoreAI', color: '#1DA1F2' },
    { icon: <Instagram />, key: 'contact.instagram', href: 'https://instagram.com/TopScoreAI', color: '#E4405F' },
];

export default function Contact() {
    const { t } = useLocale();

    return (
        <main className="min-h-screen bg-[#0A0A0F]">
            <Nav />
            <section className={styles.section}>
                <div className="container mx-auto px-4 pt-32 pb-20">
                    <AnimatedSection animation="fadeUp">
                        <div className="text-center mb-16">
                            <div className={styles.label}>{t('contact.label' as any)}</div>
                            <h1 className={styles.title}>{t('contact.title' as any)}</h1>
                            <p className={styles.sub}>{t('contact.sub' as any)}</p>
                        </div>
                    </AnimatedSection>

                    <div className={styles.grid}>
                        {contactMethods.map((m, i) => (
                            <AnimatedSection key={m.key} animation="fadeUp" delay={`${i * 0.1}s`}>
                                <a href={m.href} target="_blank" rel="noopener noreferrer" className={styles.card}>
                                    <div className={styles.iconWrapper} style={{ '--color': m.color } as any}>
                                        {m.icon}
                                    </div>
                                    <div className={styles.cardContent}>
                                        <div className={styles.cardInfo}>{t(m.key as any)}</div>
                                        <div className={styles.external}><ExternalLink size={14} /></div>
                                    </div>
                                </a>
                            </AnimatedSection>
                        ))}
                    </div>

                    <AnimatedSection animation="fadeUp" delay="0.6s">
                        <div className="text-center mt-20">
                            <a href="/features" className={styles.faqLink}>Explore our Features →</a>
                        </div>
                    </AnimatedSection>
                </div>
            </section>
            <Footer />
        </main>
    );
}
