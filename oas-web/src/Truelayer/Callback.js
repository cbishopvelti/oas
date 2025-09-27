import {useSearchParams} from 'react-router-dom'
import { useEffect, useRef } from 'react';
import { useMutation, gql } from '@apollo/client'

export const TruelayerCallback = () => {
  const [searchParams] = useSearchParams();
  const initialized = useRef(false)


  let [sendCode] = useMutation(gql`
    mutation($code: String!) {
      truelayer_callback(code: $code) {
        success
      }
    }
  `)
  const controller = new AbortController();

  useEffect(() => {
    if (!initialized.current) {
      console.log("002 ONCE please", searchParams.get("code"))
      initialized.current = true
      sendCode({
        variables: {
          code: searchParams.get("code")
        },
        context: {
          fetch: {
            signal: controller.signal
          }
        }
      })
    }
    return () => {
      console.log("003 ABORT")
      controller.abort()
    }
  }, [searchParams.get("code")]);


  return <div>Success, return to /config/truelayer and select the account.</div>
}
