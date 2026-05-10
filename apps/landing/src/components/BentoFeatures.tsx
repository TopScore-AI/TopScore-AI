'use client';
import { useLocale } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import { Brain, Headphones, GraduationCap, CloudOff, Target, Sparkles, Users, Trophy, FolderOpen } from 'lucide-react';
import styles from './BentoFeatures.module.css';

export default function BentoFeatures() {
    const { t } = useLocale();

    return (
        <section className={styles.section} id="features">
            <div className={styles.container}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.header}>
                        <h2 className={styles.title}>
                            Built for <span className="grad-text">Digital-First</span> Learning
                        </h2>
                        <p className={styles.sub}>
                            TopScore AI combines localized curriculum knowledge with state-of-the-art Generative AI to provide a premium, personal tutor for every student.
                        </p>
                    </div>
                </AnimatedSection>

                <div className={styles.grid}>
                    {/* Big Card: AI Tutor */}
                    <div className={`${styles.card} ${styles.colSpan2} ${styles.rowSpan2} glass`}>
                        <div className={styles.cardContent}>
                            <div className={styles.iconWrapper} style={{ '--color': '#3b82f6' } as any}>
                                <Headphones size={24} />
                            </div>
                            <h3 className={styles.cardTitle}>{t('features.0.title')}</h3>
                            <p className={styles.cardDesc}>{t('features.0.desc')}</p>
                        </div>
                        <div className={styles.visualAITutor}>
                             <div className={styles.aiOrb} />
                             <div className={styles.aiWave} />
                        </div>
                    </div>

                    {/* Medium Card: Curriculum */}
                    <div className={`${styles.card} glass`}>
                        <div className={styles.cardContent}>
                            <div className={styles.iconWrapper} style={{ '--color': '#10b981' } as any}>
                                <GraduationCap size={24} />
                            </div>
                            <h3 className={styles.cardTitle}>Localized Content</h3>
                            <p className={styles.cardDesc}>
                                Comprehensive support for Kenya CBC, 8-4-4, and Cambridge IGCSE curricula.
                            </p>
                        </div>
                    </div>

                    {/* Small Card: AI Study Groups (NEW) */}
                    <div className={`${styles.card} glass`}>
                        <div className={styles.cardContent}>
                            <div className={styles.iconWrapper} style={{ '--color': '#8b5cf6' } as any}>
                                <Users size={24} />
                            </div>
                            <h3 className={styles.cardTitle}>{t('features.8.title')}</h3>
                            <p className={styles.cardDesc}>{t('features.8.desc')}</p>
                        </div>
                    </div>

                    {/* Wide Card: Smart Study Tools */}
                    <div className={`${styles.card} ${styles.colSpan2} glass`}>
                        <div className={styles.cardContent}>
                            <div className="flex items-start gap-6">
                                <div className={styles.iconWrapper} style={{ '--color': '#f59e0b' } as any}>
                                    <Brain size={24} />
                                </div>
                                <div>
                                    <h3 className={styles.cardTitle}>{t('features.0.title')}</h3>
                                    <p className={styles.cardDesc}>
                                        Instantly transform PDFs and photos into interactive flashcards, concise summaries, and adaptive quizzes.
                                    </p>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Small Card: Multiplayer Learning (NEW) */}
                    <div className={`${styles.card} glass`}>
                        <div className={styles.cardContent}>
                            <div className={styles.iconWrapper} style={{ '--color': '#ec4899' } as any}>
                                <Trophy size={24} />
                            </div>
                            <h3 className={styles.cardTitle}>{t('features.9.title')}</h3>
                            <p className={styles.cardDesc}>{t('features.9.desc')}</p>
                        </div>
                    </div>

                    {/* Feature Card: Study Vault (NEW) */}
                    <div className={`${styles.card} glass`}>
                        <div className={styles.cardContent}>
                            <div className={styles.iconWrapper} style={{ '--color': '#6366f1' } as any}>
                                <FolderOpen size={24} />
                            </div>
                            <h3 className={styles.cardTitle}>{t('features.10.title')}</h3>
                            <p className={styles.cardDesc}>{t('features.10.desc')}</p>
                        </div>
                    </div>

                    {/* Feature Card: Adaptive */}
                    <div className={`${styles.card} glass`}>
                         <div className={styles.cardContent}>
                            <div className={styles.iconWrapper} style={{ '--color': '#2dd4bf' } as any}>
                                <Target size={24} />
                            </div>
                            <h3 className={styles.cardTitle}>Adaptive Learning</h3>
                            <p className={styles.cardDesc}>
                                Personalized paths that adjust to your pace and proficiency.
                            </p>
                        </div>
                    </div>

                    {/* Small Card: Offline */}
                    <div className={`${styles.card} glass`}>
                        <div className={styles.cardContent}>
                            <div className={styles.iconWrapper} style={{ '--color': '#94a3b8' } as any}>
                                <CloudOff size={24} />
                            </div>
                            <h3 className={styles.cardTitle}>Offline Mode</h3>
                            <p className={styles.cardDesc}>
                                Download resources once and study anywhere without data costs.
                            </p>
                        </div>
                    </div>
                </div>
            </div>
        </section>
    );
}
