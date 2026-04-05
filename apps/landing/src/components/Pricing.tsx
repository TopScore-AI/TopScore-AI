'use client';
import { useState } from 'react';
import { useLocale } from '@/i18n';
import type { TranslationKey } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import { Check } from "lucide-react";
import styles from './Pricing.module.css';

const plans: { idx: number; featured: boolean }[] = [
    { idx: 0, featured: false },
    { idx: 1, featured: true },
];

export default function Pricing() {
    const { t } = useLocale();
    const [period, setPeriod] = useState<'monthly' | 'annual'>('monthly');

    return (
        <section id="pricing" className={styles.wrapper}>
            <div className={styles.section}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.header}>
                        <div className={styles.label}>{t('pricing.label')}</div>
                        <h2 className={styles.title}>
                            {t('pricing.title')}<br />{t('pricing.titleBr')}
                        </h2>
                        <p className={styles.sub}>{t('pricing.sub')}</p>
                    </div>

                    <div className={styles.toggle}>
                        <div 
                            className={`${styles.toggleLabel} ${period === 'monthly' ? styles.toggleActive : ''}`}
                            onClick={() => setPeriod('monthly')}
                        >
                            {t('pricing.monthly')}
                        </div>
                        <div 
                            className={`${styles.toggleLabel} ${period === 'annual' ? styles.toggleActive : ''}`}
                            onClick={() => setPeriod('annual')}
                        >
                            {t('pricing.annual')}
                            <span className={styles.save}>{t('pricing.save')}</span>
                        </div>
                    </div>
                </AnimatedSection>

                <div className={styles.grid}>
                    {plans.map((p, i) => {
                        const nameKey = `pricing.${p.idx}.name` as TranslationKey;
                        const priceKey = (period === 'monthly' ? `pricing.${p.idx}.priceMonthly` : `pricing.${p.idx}.priceAnnual`) as TranslationKey;
                        const periodLabelKey = `pricing.${p.idx}.period` as TranslationKey;
                        const ctaKey = `pricing.${p.idx}.cta` as TranslationKey;
                        const featuresKey = `pricing.${p.idx}.features` as TranslationKey;
                        const badgeKey = `pricing.${p.idx}.badge` as TranslationKey;
                        const badge = t(badgeKey);

                        return (
                            <AnimatedSection key={p.idx} animation="fadeUp" delay={`${i * 0.12}s`}>
                                <div className={`${styles.card} ${p.featured ? styles.featured : ''}`}>
                                    {badge && badge !== badgeKey && (
                                        <div className={styles.badge}>{badge}</div>
                                    )}
                                    <h3 className={styles.planName}>{t(nameKey)}</h3>
                                    <div className={styles.price}>
                                        {t(priceKey)}
                                        <span className={styles.period}>/{period === 'monthly' ? t('pricing.mo' as any) : t('pricing.yr' as any)}</span>
                                    </div>
                                    <ul className={styles.features}>
                                        {t(featuresKey).split('|').map((f: string) => (
                                            <li key={f}>
                                                <Check className={styles.check} size={18} />
                                                <span>{f}</span>
                                            </li>
                                        ))}
                                    </ul>
                                    <a 
                                        href="/download" 
                                        className={`${styles.cta} ${p.featured ? styles.ctaPrimary : styles.ctaSecondary}`}
                                    >
                                        {t(ctaKey)}
                                    </a>
                                </div>
                            </AnimatedSection>
                        );
                    })}
                </div>
            </div>
        </section>
    );
}
