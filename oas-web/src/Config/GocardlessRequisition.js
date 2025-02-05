import { useEffect } from "react";
import { useMutation, gql } from "@apollo/client"

export const GocardlessRequisition = () => {

  const [mutation, { data, loading, error }] = useMutation(gql`
    mutation {
      gocardless_save_requistions {
        success
      }
    }
  `)

  useEffect(() => {
    mutation()
  },
  []);

  return <div>
    {error && <div>Error occurred</div>}
    {loading && <div>Please wait</div>}
    {data && <div>Success</div>}
  </div>
}
