import { useEffect, useState, useRef} from "react";
import { useMutation, gql } from "@apollo/client"

export const GocardlessRequisition = () => {
  const initialized = useRef(false)

  const [mutation, { data, loading, error }] = useMutation(gql`
    mutation {
      gocardless_save_requistions {
        success
      }
    }
  `)

  useEffect(() => {
    if (!initialized.current) {
      initialized.current = true
      mutation()
    }
  },
  []);

  return <div>
    {error && <div>Error occurred</div>}
    {loading && <div>Please wait</div>}
    {data && <div>Success, please go back to gocardless config and select the account.</div>}
  </div>
}
