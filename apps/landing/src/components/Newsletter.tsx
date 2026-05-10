'use client';
import { useState } from 'react';
import { collection, addDoc, serverTimestamp } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import { useLocale } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import styles from './Newsletter.module.css';

export default function Newsletter() {
    const { t } = useLocale();
    const [email, setEmail] = useState('');
    const [submitted, setSubmitted] = useState(false);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState('');

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!email || loading) return;

        setLoading(true);
        setError('');

        try {
            await addDoc(collection(db, 'newsletter_subscribers'), {
                email: email.trim().toLowerCase(),
                subscribedAt: serverTimestamp(),
                source: 'landing_page',
            });

            // Also keep a local record so we don't re-prompt on the same device
            try {
                const list = JSON.parse(localStorage.getItem('topscore_newsletter') ?? '[]');
                list.push({ email, date: new Date().toISOString() });
                localStorage.setItem('topscore_newsletter', JSON.stringify(list));
            } catch { /* noop */ }

            setSubmitted(true);
        } catch (err) {
            console.error('Newsletter subscribe error:', err);
            setError(t('newsletter.error' as any) || 'Something went wrong. Please try again.');
        } finally {
            setLoading(false);
        }
    };

    return (
        <section className={styles.wrapper}>
            <div className={styles.inner}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.label}>{t('newsletter.label')}</div>
                    <h2 className={styles.title}>{t('newsletter.title')}</h2>
                    <p className={styles.sub}>{t('newsletter.sub')}</p>
                </AnimatedSection>

                <AnimatedSection animation="fadeUp" delay="0.15s">
                    {submitted ? (
                        <div className={styles.success}>
                            ✅ {t('newsletter.success')}
                        </div>
                    ) : (
                        <form className={styles.form} onSubmit={handleSubmit}>
                            <Input
                                type="email"
                                className={styles.input}
                                placeholder={t('newsletter.placeholder')}
                                value={email}
                                onChange={(e) => setEmail(e.target.value)}
                                required
                            />
                            <Button type="submit" className={styles.btn} disabled={loading} size="lg">
                                {loading ? '...' : t('newsletter.cta')}
                            </Button>
                            {error && (
                                <p className={styles.error ?? 'text-red-500 text-sm mt-2'}>{error}</p>
                            )}
                        </form>
                    )}
                </AnimatedSection>
            </div>
        </section>
    );
}
