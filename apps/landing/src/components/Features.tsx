'use client';
import { useLocale } from '@/i18n';
import type { TranslationKey } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import styles from './Features.module.css';

const featureMeta: { icon: string; bg: string; idx: number }[] = [
    { icon: '🎙️', bg: 'linear-gradient(135deg, #2563EB, #3B82F6)', idx: 7 }, // Live Voice (New priority)
    { icon: '✍️', bg: 'linear-gradient(135deg, #8B5CF6, #A855F7)', idx: 6 }, // AI Composition (New priority)
    { icon: '🤖', bg: 'linear-gradient(135deg, #3B82F6, #2D9A7C)', idx: 0 }, // AI Tutor
    { icon: '📚', bg: 'linear-gradient(135deg, #10B981, #3B82F6)', idx: 1 }, // Library
    { icon: '🔥', bg: 'linear-gradient(135deg, #F97316, #EF4444)', idx: 2 }, // Streaks
    { icon: '📊', bg: 'linear-gradient(135deg, #6366F1, #8B5CF6)', idx: 3 }, // Reports
    { icon: '📶', bg: 'linear-gradient(135deg, #475569, #0F172A)', idx: 4 }, // Offline
    { icon: '🔍', bg: 'linear-gradient(135deg, #EC4899, #F43F5E)', idx: 5 }, // Search
];

export default function Features({ limit }: { limit?: number }) {
    const { t } = useLocale();
    const items = limit ? featureMeta.slice(0, limit) : featureMeta;

    return (
        <section id="features" className={styles.wrapper}>
            <div className={styles.section}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.header}>
                        <div className={styles.label}>{t('features.label')}</div>
                        <h2 className={`${styles.title} font-serif`}>
                            {t('features.title')}<br />{t('features.titleBr')}
                        </h2>
                        <p className={`${styles.sub} prose-editorial`}>
                            {t('features.sub')}
                        </p>
                    </div>
                </AnimatedSection>

                <div className={styles.grid}>
                    {items.map((f, i) => {
                        const titleKey = `features.${f.idx}.title` as any;
                        const descKey = `features.${f.idx}.desc` as any;
                        const tagsKey = `features.${f.idx}.tags` as any;
                        return (
                            <AnimatedSection key={f.idx} animation="fadeUp" delay={`${i * 0.05}s`}>
                                <div className={styles.cardWrapper}>
                                    <Card className={styles.card}>
                                        <div className={styles.cardGlow} style={{ background: f.bg }} />
                                        <div className={styles.icon} style={{ background: f.bg }}>
                                            {f.icon}
                                        </div>
                                        <CardHeader className="p-0 space-y-2 relative z-10">
                                            <h3 className={`${styles.cardTitle} font-serif`}>{t(titleKey)}</h3>
                                        </CardHeader>
                                        <CardContent className="p-0 pt-2 pb-4 relative z-10">
                                            <p className={styles.cardDesc}>{t(descKey)}</p>
                                        </CardContent>
                                        <div className={styles.tags}>
                                            {t(tagsKey).split(',').map((tag: string) => (
                                                <span className={styles.tag} key={tag}>{tag}</span>
                                            ))}
                                        </div>
                                    </Card>
                                </div>
                            </AnimatedSection>
                        );
                    })}
                </div>
            </div>
        </section>
    );
}
