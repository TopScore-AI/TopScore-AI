'use client';
import { useLocale } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import { Shield, Lock, BookOpen, Users } from 'lucide-react';
import styles from './Safety.module.css';

const safetyFeatures = [
    { icon: Shield, idx: 0 },
    { icon: Lock, idx: 1 },
    { icon: BookOpen, idx: 2 },
    { icon: Users, idx: 3 },
];

export default function Safety() {
    const { t } = useLocale();

    return (
        <section className={styles.wrapper}>
            <div className={styles.section}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.header}>
                        <div className={styles.label}>{t('safety.label')}</div>
                        <h2 className={styles.title}>{t('safety.title')}</h2>
                        <p className={styles.sub}>{t('safety.sub')}</p>
                    </div>
                </AnimatedSection>

                <div className={styles.grid}>
                    {safetyFeatures.map((f, i) => {
                        const Icon = f.icon;
                        const titleKey = `safety.${f.idx}.title` as any;
                        const descKey = `safety.${f.idx}.desc` as any;

                        return (
                            <AnimatedSection key={i} animation="fadeUp" delay={`${i * 0.1}s`}>
                                <div className={styles.card}>
                                    <div className={styles.iconWrapper}>
                                        <Icon size={24} />
                                    </div>
                                    <h3 className={styles.cardTitle}>{t(titleKey)}</h3>
                                    <p className={styles.cardDesc}>{t(descKey)}</p>
                                </div>
                            </AnimatedSection>
                        );
                    })}
                </div>
            </div>
        </section>
    );
}
