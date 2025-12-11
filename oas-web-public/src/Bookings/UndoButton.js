import { Button } from "@mui/material"
import { useEffect, useState } from "react";
import moment from 'moment';
import { padStart } from 'lodash'


export const UndoButton = ({
  expires,
  refetch,
  state,
  setState,
  onClick
}) => {
  const [countdown, setCountdown] = useState({});

  useEffect(() => {
    let interval = null
    const doTimer = () => {
      setCountdown({
        seconds: padStart(expires.diff(moment(), 'seconds') % 60, 2, '0'),
        minutes: padStart(expires.diff(moment(), 'minutes') % 60, 2, '0'),
        hours: padStart(expires.diff(moment(), 'hours'), 2, '0')

      });
      if (expires.diff(moment(), 'seconds') < 0) {
        interval && clearInterval(interval)
        refetch();
        setState({ // Force update
          ...state,
          update: state.update + 1
        })
      }
    }

    doTimer()
    interval = setInterval(doTimer, 1000);

    return () => {
      clearInterval(interval);
    }
  }, []);

  return <Button sx={{width: '100%'}} color="warning" onClick={onClick}>
    {countdown.hours}:{countdown.minutes}:{countdown.seconds} Undo
  </Button>
}
