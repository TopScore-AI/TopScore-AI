'use client';
import { useLocale } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import styles from './CompositionShowcase.module.css';

export default function CompositionShowcase() {
    const { t } = useLocale();

    return (
        <section className={styles.wrapper}>
            <div className={styles.container}>
                <div className={styles.header}>
                    <AnimatedSection animation="fadeUp">
                        <div className={styles.label}>{t('showcase.label')}</div>
                        <h2 className={styles.title}>{t('showcase.title')}</h2>
                        <p className={styles.sub}>{t('showcase.sub')}</p>
                    </AnimatedSection>
                </div>

                <div className={styles.grid}>
                    {/* Editor Side */}
                    <AnimatedSection animation="fadeUp" delay="0.1s">
                        <div className={styles.editor}>
                            <div className={styles.editorHeader}>
                                <div className={styles.dotRed} />
                                <div className={styles.dotYellow} />
                                <div className={styles.dotGreen} />
                                <span className={styles.editorTitle}>{t('showcase.editor.title')}</span>
                            </div>
                            <div className={styles.editorContent}>
                                <p className={styles.typedText}>
                                    {t('showcase.editor.placeholder')}
                                    <span className={styles.cursor}>|</span>
                                </p>
                                <div className={styles.placeholderLines}>
                                    <div className={styles.line} />
                                    <div className={styles.lineShort} />
                                    <div className={styles.line} />
                                </div>
                            </div>
                        </div>
                    </AnimatedSection>

                    {/* Grading Side */}
                    <AnimatedSection animation="fadeUp" delay="0.2s">
                        <div className={styles.grading}>
                            <h3 className={styles.gradingTitle}>{t('showcase.grading.title')}</h3>
                            
                            <div className={styles.scoreCircle}>
                                <svg viewBox="0 0 36 36" className={styles.circularChart}>
                                    <path className={styles.circleBg} d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" />
                                    <path className={styles.circle} strokeDasharray="85, 100" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" />
                                    <text x="18" y="20.35" className={styles.percentage}>85%</text>
                                </svg>
                                <span>{t('showcase.grading.score')}</span>
                            </div>

                            <div className={styles.metrics}>
                                <div className={styles.metric}>
                                    <div className={styles.metricLabel}>
                                        <span>{t('showcase.grading.grammar')}</span>
                                        <span>18/20</span>
                                    </div>
                                    <div className={styles.bar}><div className={styles.fill} style={{ width: '90%' }} /></div>
                                </div>
                                <div className={styles.metric}>
                                    <div className={styles.metricLabel}>
                                        <span>{t('showcase.grading.vocabulary')}</span>
                                        <span>16/20</span>
                                    </div>
                                    <div className={styles.bar}><div className={styles.fill} style={{ width: '80%' }} /></div>
                                </div>
                            </div>

                            <div className={styles.feedback}>
                                <strong>{t('showcase.grading.feedback')}</strong>
                                <p>{t('showcase.grading.tips')}</p>
                            </div>
                        </div>
                    </AnimatedSection>
                </div>
            </div>
        </section>
    );
}
