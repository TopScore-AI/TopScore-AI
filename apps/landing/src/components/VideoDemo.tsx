'use client';
import { useState } from 'react';
import { useLocale } from '@/i18n';
import AnimatedSection from './AnimatedSection';
import { Play } from 'lucide-react';
import styles from './VideoDemo.module.css';

// Replace this with the actual TopScore AI demo video ID when available
const YOUTUBE_VIDEO_ID = '';

export default function VideoDemo() {
    const { t } = useLocale();
    const [playing, setPlaying] = useState(false);

    // Don't render the section at all if no video ID is set
    if (!YOUTUBE_VIDEO_ID) return null;

    return (
        <section id="demo" className={styles.wrapper}>
            <div className={styles.section}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.label}>{t('video.label')}</div>
                    <h2 className={styles.title}>{t('video.title')}</h2>
                    <p className={styles.sub}>{t('video.sub')}</p>
                </AnimatedSection>

                <AnimatedSection animation="fadeUp" delay="0.2s">
                    <div className={styles.videoWrap}>
                        {playing ? (
                            <iframe
                                src={`https://www.youtube.com/embed/${YOUTUBE_VIDEO_ID}?rel=0&autoplay=1`}
                                title={t('video.title')}
                                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                                allowFullScreen
                                className={styles.iframe}
                            />
                        ) : (
                            <button className={styles.thumbnail} onClick={() => setPlaying(true)} aria-label="Play video">
                                <img
                                    src={`https://img.youtube.com/vi/${YOUTUBE_VIDEO_ID}/maxresdefault.jpg`}
                                    alt={t('video.title')}
                                    className={styles.thumbImg}
                                />
                                <div className={styles.playBtn}>
                                    <Play className={styles.playIcon} />
                                </div>
                            </button>
                        )}
                    </div>
                </AnimatedSection>
            </div>
        </section>
    );
}
