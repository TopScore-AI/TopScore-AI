'use client';
import { useLocale } from '@/i18n';
import type { TranslationKey } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import styles from './HowItWorks.module.css';

const stepNums = ['1', '2', '3', '4'];

export default function HowItWorks() {
    const { t } = useLocale();

    return (
        <section className={styles.section} id="how-it-works">
            <div className={styles.container}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.header}>
                        <div className={styles.label}>{t('howItWorks.label')}</div>
                        <h2 className={styles.title}>{t('howItWorks.title')}</h2>
                        <p className={styles.sub}>
                            {t('howItWorks.sub')}
                        </p>
                    </div>
                </AnimatedSection>

                <div className={styles.grid}>
                    {stepNums.map((num, i) => {
                        const titleKey = `howItWorks.${i}.title` as TranslationKey;
                        const descKey = `howItWorks.${i}.desc` as TranslationKey;

                        return (
                            <div key={num} className={styles.step}>
                                <AnimatedSection animation="fadeUp" delay={`${i * 0.12}s`}>
                                    <div className={styles.number}>{num}</div>
                                    <h3 className={styles.stepTitle}>{t(titleKey)}</h3>
                                    <p className={styles.stepDesc}>{t(descKey)}</p>
                                </AnimatedSection>
                            </div>
                        );
                    })}
                </div>

                {/* Web App Guide Section */}
                <div className={styles.webappSection}>
                    <AnimatedSection animation="fadeUp">
                        <div className={styles.header} style={{ marginTop: '5rem' }}>
                            <h2 className={styles.title}>{t('howItWorks.webapp.title')}</h2>
                        </div>
                    </AnimatedSection>
                    
                    <div className={styles.grid}>
                        {[0, 1, 2, 3].map((idx) => {
                            const titleKey = `howItWorks.webapp.${idx}.title` as TranslationKey;
                            const descKey = `howItWorks.webapp.${idx}.desc` as TranslationKey;
                            return (
                                <div key={idx} className={styles.step}>
                                    <AnimatedSection animation="fadeUp" delay={`${idx * 0.12}s`}>
                                        <div className={styles.number} style={{ fontSize: '1.2rem', opacity: 0.7 }}>{idx + 1}</div>
                                        <h3 className={styles.stepTitle}>{t(titleKey)}</h3>
                                        <p className={styles.stepDesc}>{t(descKey)}</p>
                                    </AnimatedSection>
                                </div>
                            );
                        })}
                    </div>
                </div>
            </div>
        </section>
    );
}
