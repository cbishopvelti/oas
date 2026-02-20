import { useRef, useEffect } from 'react';

export const usePrevious = (value) => {
  const ref = useRef();

  useEffect(() => {
    ref.current = value;
  }, [value]); // Update ref AFTER the render cycle

  return ref.current; // Return the OLD value (before update)
}
