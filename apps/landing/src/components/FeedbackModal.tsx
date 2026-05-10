'use client';
import { useState } from 'react';
import { collection, addDoc, serverTimestamp } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import { useLocale } from '@/i18n';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Star, Send, Loader2, CheckCircle2 } from "lucide-react";

interface FeedbackModalProps {
    isOpen: boolean;
    onClose: () => void;
}

export default function FeedbackModal({ isOpen, onClose }: FeedbackModalProps) {
    const { t } = useLocale();
    const [rating, setRating] = useState(0);
    const [name, setName] = useState('');
    const [text, setText] = useState('');
    const [submitting, setSubmitting] = useState(false);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState(false);

    const handleClose = () => {
        // Reset state when closing
        setRating(0);
        setName('');
        setText('');
        setError('');
        setSuccess(false);
        onClose();
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');

        if (rating === 0) {
            setError('Please select a star rating.');
            return;
        }
        if (!name.trim()) {
            setError('Please enter your name.');
            return;
        }
        if (!text.trim()) {
            setError('Please write your feedback.');
            return;
        }

        setSubmitting(true);
        try {
            await addDoc(collection(db, "testimonials"), {
                name: name.trim(),
                rating,
                text: text.trim(),
                approved: false,
                createdAt: serverTimestamp(),
                source: 'web'
            });
            setSuccess(true);
        } catch (err) {
            console.error("Error submitting feedback:", err);
            setError("Failed to submit. Please try again.");
        } finally {
            setSubmitting(false);
        }
    };

    return (
        <Dialog open={isOpen} onOpenChange={handleClose}>
            <DialogContent className="sm:max-w-[425px]">
                {success ? (
                    <div className="flex flex-col items-center gap-4 py-8 text-center">
                        <CheckCircle2 className="h-16 w-16 text-green-500" />
                        <DialogTitle className="text-2xl font-black font-fredoka">Thank you!</DialogTitle>
                        <DialogDescription className="font-lexend">
                            Your feedback has been submitted for review. It may appear on our site soon.
                        </DialogDescription>
                        <Button onClick={handleClose} className="mt-2 font-lexend">Close</Button>
                    </div>
                ) : (
                    <form onSubmit={handleSubmit}>
                        <DialogHeader>
                            <DialogTitle className="text-2xl font-black font-fredoka">Share Your Experience</DialogTitle>
                            <DialogDescription className="font-lexend">
                                How is TopScore AI helping you? Your testimonial might be featured on our landing page.
                            </DialogDescription>
                        </DialogHeader>
                        <div className="grid gap-6 py-6">
                            <div className="flex flex-col items-center gap-3">
                                <span className="text-sm font-medium font-lexend text-muted-foreground">Rating</span>
                                <div className="flex gap-1">
                                    {[1, 2, 3, 4, 5].map((s) => (
                                        <button
                                            key={s}
                                            type="button"
                                            onClick={() => setRating(s)}
                                            className="transition-all hover:scale-110"
                                        >
                                            <Star
                                                className={`h-8 w-8 ${s <= rating ? 'fill-yellow-500 text-yellow-500' : 'text-muted-foreground/30'}`}
                                            />
                                        </button>
                                    ))}
                                </div>
                            </div>
                            <div className="grid gap-2">
                                <label htmlFor="name" className="text-sm font-bold font-lexend">Your Name</label>
                                <Input
                                    id="name"
                                    value={name}
                                    onChange={(e) => setName(e.target.value)}
                                    placeholder="e.g. Amina K."
                                    className="font-lexend"
                                />
                            </div>
                            <div className="grid gap-2">
                                <label htmlFor="text" className="text-sm font-bold font-lexend">Your Feedback</label>
                                <Textarea
                                    id="text"
                                    value={text}
                                    onChange={(e) => setText(e.target.value)}
                                    placeholder="Tell us how we helped you..."
                                    className="min-h-[100px] font-lexend"
                                />
                            </div>
                            {error && (
                                <p className="text-sm text-red-500 font-lexend">{error}</p>
                            )}
                        </div>
                        <DialogFooter>
                            <Button
                                type="submit"
                                disabled={submitting}
                                className="w-full font-black font-lexend py-6 text-lg"
                            >
                                {submitting ? (
                                    <Loader2 className="mr-2 h-5 w-5 animate-spin" />
                                ) : (
                                    <Send className="mr-2 h-5 w-5" />
                                )}
                                Submit Testimonial
                            </Button>
                        </DialogFooter>
                    </form>
                )}
            </DialogContent>
        </Dialog>
    );
}
