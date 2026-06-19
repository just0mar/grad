import { motion, AnimatePresence } from 'framer-motion';
import { X } from 'lucide-react';
import { modalOverlay, modalContent } from '../animations/variants';

export default function Modal({ isOpen, onClose, title, children }) {
  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          className="fixed inset-0 z-[60] flex items-center justify-center p-4"
          variants={modalOverlay}
          initial="initial"
          animate="animate"
          exit="exit"
        >
          {/* Backdrop */}
          <div
            className="absolute inset-0 bg-black/50 backdrop-blur-sm"
            onClick={onClose}
          />
          {/* Content */}
          <motion.div
            variants={modalContent}
            initial="initial"
            animate="animate"
            exit="exit"
            className="relative bg-white dark:bg-surface-dark rounded-2xl shadow-2xl w-full max-w-md max-h-[85vh] overflow-y-auto"
          >
            {/* Header */}
            {title && (
              <div className="flex items-center justify-between p-4 border-b border-gray-200 dark:border-white/10">
                <h3 className="text-card-title dark:text-white">{title}</h3>
                <button
                  onClick={onClose}
                  className="p-1.5 rounded-full hover:bg-gray-100 dark:hover:bg-white/10 transition-colors"
                  aria-label="Close"
                >
                  <X size={20} className="dark:text-white" />
                </button>
              </div>
            )}
            {/* Body */}
            <div className="p-4">{children}</div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
