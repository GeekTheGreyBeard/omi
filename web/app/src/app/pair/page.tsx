import type { Metadata } from 'next';
import { PairDeviceClient } from './PairDeviceClient';

export const metadata: Metadata = {
  title: 'Pair Device',
  description: 'Pair an Omi device to approve web portal login.',
};

export default function PairDevicePage() {
  return <PairDeviceClient />;
}
