import { useState, useEffect } from 'react';
import moment from 'moment';
import { Box } from '@mui/material'
import { padStart } from 'lodash';

export const TrainingAttendanceRowUndo = ({
  attendance,
  refetch,
  expires,
  state,
  setState
}) => {
  const [countdown, setCountdown] = useState({});

  useEffect(() => {
    const doTimer = () => {
      setCountdown({
        seconds: padStart(expires.diff(moment(), 'seconds') % 60, 2, '0'),
        minutes: padStart(expires.diff(moment(), 'minutes') % 60, 2, '0'),
        hours: padStart(expires.diff(moment(), 'hours'), 2, '0')
        
      });
      if (expires.diff(moment(), 'seconds') < 0) {
        clearInterval(interval)
        refetch();
        setState({ // Force update
          ...state,
          update: state.update + 1
        })
      }
    }

    doTimer()

    const interval = setInterval(doTimer, 1000);
    return () => {
      clearInterval(interval);
    }
  }, []);

  return <Box sx={{display: 'inline-block'}}>
    {countdown.hours}:{countdown.minutes}:{countdown.seconds}
  </Box>
}