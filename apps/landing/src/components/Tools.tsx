'use client';
import { useLocale } from '@/i18n';
import type { TranslationKey } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import styles from './Tools.module.css';

const toolMeta: { icon: string; idx: number }[] = [
    { icon: '📝', idx: 0 }, // Quiz
    { icon: '📈', idx: 1 }, // Graphs
    { icon: '🗺️', idx: 2 }, // Flow charts
    { icon: '🖼️', idx: 3 }, // Image search
    { icon: '🥽', idx: 4 }, // Simulations
    { icon: '📷', idx: 5 }, // Scanner
    { icon: '🧮', idx: 6 }, // Calculator
    { icon: '🃏', idx: 7 }, // Flashcards
    { icon: '🧬', idx: 8 }, // Periodic Table
    { icon: '⚗️', idx: 9 }, // Science Lab
    { icon: '🔍', idx: 10 }, // Search
    { icon: '📖', idx: 11 }, // PDF
];

export default function Tools() {
    const { t } = useLocale();

    return (
        <section id="tools" className={styles.wrapper}>
            <div className={styles.section}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.label}>{t('tools.label')}</div>
                    <h2 className={styles.title}>
                        {t('tools.title')}<br />{t('tools.titleBr')}
                    </h2>
                    <p className={styles.sub}>
                        {t('tools.sub')}
                    </p>
                </AnimatedSection>

                <div className={styles.strip}>
                    {toolMeta.map((tm, i) => {
                        const nameKey = `tools.${tm.idx}.name` as TranslationKey;
                        const descKey = `tools.${tm.idx}.desc` as TranslationKey;
                        return (
                            <AnimatedSection key={tm.idx} animation="fadeUp" delay={`${i * 0.06}s`}>
                                <div className={styles.item}>
                                    <div className={styles.icon}>{tm.icon}</div>
                                    <h3 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '0.25rem' }}>{t(nameKey)}</h3>
                                    <p>{t(descKey)}</p>
                                </div>
                            </AnimatedSection>
                        );
                    })}
                </div>
            </div>
        </section>
    );
}
