import {useState, forwardRef, useEffect, useRef } from 'react';
import TextField from '@mui/material/TextField';
import Stack from '@mui/material/Stack';
import { styled } from '@mui/material/styles';


// 1. Invisible input styles
const StyledInput = styled('input')(({ theme }) => ({
  width: '60px', // Slightly wider to accommodate negative sign
  border: 'none',
  outline: 'none',
  textAlign: 'right', // Right align hours so it sits next to colon
  fontSize: 'inherit',
  fontFamily: 'inherit',
  backgroundColor: 'transparent',
  color: 'currentColor',
  '&::placeholder': {
    color: theme.palette.text.disabled,
  },
}));

// 2. The Custom Slot
const DurationInputSlot = forwardRef(function DurationInputSlot(props, ref) {
  const { value, onChange, ...other } = props;
  const [hours, setHours] = useState('');
  const [minutes, setMinutes] = useState('');
  // const [focusTimeout, setFocusTimeout] = useState(null);
  // const [isFocused, setIsFocused] = useState(false);
  const focusTimeoutRef = useRef(null);

  useEffect(() => {
    if (value) {
      const parts = value.match(/([+-])?PT(\d+)H(\d+)M/)
      setHours(parseInt(`${parts[1]|| ''}${parts[2]}`))
      setMinutes(parseInt(parts[3]))
    }
  }, [value])

  const doOnChange = () => {

    if (!isNaN(parseInt(hours)) && !isNaN(parseInt(minutes)) && parseInt(minutes) >=0 && parseInt(minutes) <= 59) {
      onChange({target: {
        value: `${parseInt(hours) < 0 ? '-' : ''}PT${Math.abs(parseInt(hours))}H${parseInt(minutes)}M`
      }})
    } else {
      setHours('')
      setMinutes('')
      onChange({target: {
        value: null
      }})
    }
  }
  useEffect(() => {
    if (!isNaN(parseInt(hours)) && !isNaN(parseInt(minutes)) && parseInt(minutes) >=0 && parseInt(minutes) <= 59) {
      onChange({target: {
        value: `${parseInt(hours) < 0 ? '-' : ''}PT${Math.abs(parseInt(hours))}H${parseInt(minutes)}M`
      }})
    }
  }, [hours, minutes])

  // HANDLER: Hours
  const handleHoursChange = (e) => {
    const rawInput = e.target.value;
    setHours(rawInput)
    // onChange({ target: { value: `${isNegative ? '-' : '+'}PT${newValue}H${parts[3]}M` } })
  };

  // HANDLER: Minutes
  const handleMinutesChange = (e) => {
    let rawInput = e.target.value

    // // Cap at 59
    if (parseInt(rawInput, 10) > 59) rawInput = '59';
    if (parseInt(rawInput, 10) < 0) rawInput = '0';

    setMinutes(rawInput)

    // // Reconstruct (preserve current negative state)
    // const prefix = isNegative ? '-' : '';
    // const currentHours = hStr;

    // onChange({ target: { value: `${parts[1]}PT${parts[2]}H${parseInt(rawInput) || 0}M` } });
  };

  const focusTimeout = () => {
    doOnChange();
  }

  return (
    <Stack direction="row" alignItems="center" spacing={0.5} ref={ref} {...other}>
      <StyledInput
        sx={{width: "33px"}}
        placeholder="HH"
        // Display value: Add minus sign back if needed
        value={hours}
        onChange={handleHoursChange}
        onFocus={() => {
          clearTimeout(focusTimeoutRef.current)
          focusTimeoutRef.current = null;

        }}
        onBlur={() => {
          clearTimeout(focusTimeoutRef.current)
          focusTimeoutRef.current = setTimeout(focusTimeout, 10)

          // setFocusTimeout((timeout) => {
          //   clearTimeout(timeout)
          //   const out = setTimeout(() => {
          //     console.log("102.2 --- DO FULL BLUR")
          //   }, 200)
          //   console.log("102.3", out)
          //   return out;
          // })
        }}
      />
      <span>:</span>
      <StyledInput
        placeholder="MM"
        value={minutes}
        onChange={handleMinutesChange}
        maxLength={2}
        style={{ textAlign: 'left', width: '40px' }} // Left align minutes
        onFocus={() => {
          clearTimeout(focusTimeoutRef.current)
          focusTimeoutRef.current = null;
        }}
        onBlur={() => {
          clearTimeout(focusTimeoutRef.current)
          focusTimeoutRef.current = setTimeout(focusTimeout, 10)
        }}
      />
    </Stack>
  );
});

// 3. The Usage Component
export default function OffsetField({
  label,
  value,
  onChange
}) {

  return (
    <TextField
      label={label}
      value={value}
      onChange={onChange}
      InputProps={{
        inputComponent: DurationInputSlot,
      }}
      InputLabelProps={{
        shrink: true,
      }}
      helperText={
        <span>
          Format: <strong>(-)HH:MM</strong>. Allows &gt;24h.
        </span>
      }
    />
  );
}
