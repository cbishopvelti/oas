import { get, omit, uniqBy } from 'lodash'
import { useQuery, useLazyQuery, gql} from '@apollo/client';
import { useOutletContext, Link, useParams, useSearchParams } from 'react-router-dom'
import { Alert, Box } from '@mui/material';
import { useEffect } from 'react';



export const CreditWarning = ({
  watch
}) => {
  const [outletContext] = useOutletContext();
  const [params, setParams] = useSearchParams()

  const member_email = get(outletContext, 'user.email')

  const { data, error, refetch } = useQuery(gql`
    query($email: String!) {
      public_credits(email: $email) {
        id,
        what,
        expires_on,
        when,
        amount,
        after_amount
      }
      public_bacs(email: $email)
    }
    `, {
    variables: {
      email: member_email
    },
    skip: !member_email
  })
  useEffect(() => {
    refetch()
  }, [watch])

  const credits = get(data, 'public_credits', []);
  const errors = uniqBy(get(error, 'graphQLErrors', []), "message")

  const currentBalance = credits.length > 0 ?
     credits[0].after_amount :
     0;

  useEffect(() => {
    const timer = setTimeout(() => {
      setParams({ ...omit(params, "error") })
    }, 120_00);

    return () => clearTimeout(timer);
  }, []);

  return <Box sx={{ gap: "12px", display: "flex", flexDirection: "column" }}>
    {
      params.get("error-full") && <Alert severity='error'>
        This event is full. You have not been booked in. Please contact an admin.
      </Alert>
    }
    {currentBalance < 0 && <Alert severity="warning">
      Your current balance is <b style={{ ...currentBalance < 0 ? { color: "red" } : { }}}>{ currentBalance }</b> please purchase more credits. Insturctions <Link to="/credits">here</Link>.
    </Alert>}
    {
      params.get("error") && <Alert severity="info">
        You have already booked into this session.
      </Alert>
    }
  </Box>
}
