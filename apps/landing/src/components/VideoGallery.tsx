'use client';
import AnimatedSection from './AnimatedSection';
import styles from './VideoGallery.module.css';

const videos = [
    {
        id: '1',
        title: 'How to use TopScore AI Tutor',
        thumbnail: 'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
        duration: '2:45',
    },
    {
        id: '2',
        title: 'Scanning Math Problems',
        thumbnail: 'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
        duration: '1:30',
    },
    {
        id: '3',
        title: 'Downloading KCSE Past Papers',
        thumbnail: 'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
        duration: '3:15',
    },
];

export default function VideoGallery() {
    return (
        <section className={styles.gallery} id="tutorials">
            <div className={styles.container}>
                <AnimatedSection animation="fadeUp">
                    <div className={styles.header}>
                        <h2 className={styles.title}>See It In Action</h2>
                        <p className={styles.subtitle}>Watch short tutorials on how to get the most out of TopScore AI.</p>
                    </div>
                </AnimatedSection>

                <div className={styles.grid}>
                    {videos.map((video, index) => (
                        <AnimatedSection animation="fadeUp" delay={`${index * 0.15}s`} key={video.id}>
                            <div className={styles.videoCard}>
                                <div className={styles.thumbnailContainer}>
                                    <div className={styles.playButton}>
                                        <div className={styles.playIcon} />
                                    </div>
                                    {/* Placeholder for actual next/image or video embed */}
                                    <img src={video.thumbnail} alt={video.title} className={styles.thumbnail} />
                                    <span className={styles.duration}>{video.duration}</span>
                                </div>
                                <h3 className={styles.videoTitle}>{video.title}</h3>
                            </div>
                        </AnimatedSection>
                    ))}
                </div>
            </div>
        </section>
    );
}