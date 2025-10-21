import { useSearchParams } from "react-router-dom";
import { useQuery, gql } from "@apollo/client";
import { has, get } from 'lodash'


export const MembershipSuccess = () => {
  const [searchParams, setSearchParams] = useSearchParams();

  const member_email = searchParams.get('email') || '';

  const { data, error } = useQuery(gql`
    query($email: String!) {
      public_bacs(email: $email)
    }
  `, {
    variables: {
      email: member_email
    },
    skip: !member_email
  })

  return <>
    <h2>Success</h2>
    <p>
      Thank you for registering. You are now a temporary member, you can go to 3 jams before you must become a full member.
    </p>
    {has(data, 'public_bacs') && <>
      <p>To buy credits please transfer money to:</p>
      <pre>
      {get(data, 'public_bacs').map((item) => <>{item}<br/></>)}
      </pre>
    </>}
    <p>
    Credits are valid for one year from purchase and are non-refundable. Credits can be transferred between members.<br/>
    </p>
  </>
}
