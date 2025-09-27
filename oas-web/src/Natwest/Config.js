import { Button, FormControl } from '@mui/material';
import { NavLink } from 'react-router-dom';


export const NatwestConfig = () => {

  return <div>

    <FormControl fullWidth>
      <Button
        LinkComponent={NavLink}
        to="/natwest/auth-flow"

      >
        Authroize bank
      </Button>
    </FormControl>
  </div>
}
