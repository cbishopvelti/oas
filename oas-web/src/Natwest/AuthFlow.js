import { Button, FormControl  } from '@mui/material'
import { useState, useRef, useEffect } from 'react';
import { useMutation, gql } from '@apollo/client';
import { useSearchParams } from 'react-router-dom'
import { trimStart } from 'lodash';

export const NatwestAuthFlow = () => {
  let [step, setStep] = useState(1);

  let [generateLink, {data}] = useMutation(gql`
    mutation {
      natwest_generate_link {
        link
      }
    }
  `)

  const getAuthLink = () => {
    generateLink()
  }

  return <div>
    <FormControl fullWidth>
      <Button onClick={ getAuthLink } >
        Generate Auth Link
      </Button>
      {data?.natwest_generate_link?.link && <div>
        <a href={data.natwest_generate_link?.link}>{ data.natwest_generate_link?.link}</a>
      </div>}
    </FormControl>

  </div>
}

export const NatwestCallback = () => {
  const [searchParams] = useSearchParams(trimStart(window.location.hash, '#'));
  const initialized = useRef(false)

  console.log("000", searchParams)

  const [exchange] = useMutation(gql`
    mutation($code: String!, $id_token: String) {
      natwest_exchange_code(code: $code, id_token: $id_token) {
        success
      }
    }
  `)

  console.log("001 code", searchParams.get("code"))

  useEffect(() => {
    if (!initialized.current) {
      console.log("002 ONCE please", searchParams.get("code"))
      initialized.current = true
      exchange({
        variables: {
          code: searchParams.get("code"),
          id_token: searchParams.get("id_token")
        }
      })
    }

  }, [searchParams.get("code")]);

  return <div>
    Success
  </div>
}
