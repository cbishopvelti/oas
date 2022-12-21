import { Button } from "@mui/material"
import { useEffect, useState } from "react";
import moment from 'moment';
import { padStart } from 'lodash'


export const UndoButton = ({
  expires,
  refetch
}) => {
  const [countdown, setCountdown] = useState({});

  useEffect(() => {
    const doTimer = () => {
      setCountdown({
        seconds: padStart(expires.diff(moment(), 'seconds') % 60, 2, '0'),
        minutes: padStart(expires.diff(moment(), 'minutes') % 60, 2, '0'),
        hours: padStart(expires.diff(moment(), 'hours'), 2, '0')
        
      });
      if (expires.diff(moment(), 'seconds') <= 0) {
        refetch();
      }
    }

    doTimer()

    const interval = setInterval(doTimer, 1000);
    return () => {
      clearInterval(interval);
    }
  }, []);

  return <Button sx={{width: '100%'}} color="warning">
    {countdown.hours}:{countdown.minutes}:{countdown.seconds} Undo
  </Button>
}